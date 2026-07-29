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

-- ===== Shared cyberpunk palette (docs/49 HUD modernization). One place for the HUD's identity
-- colors so every widget reads as ONE device. Floats are LUI setRGB units (0..1). =====
local ACC_PAL = {
    glass  = { 0,    0.035, 0.085 },  -- dark navy panel base (the universal plate)
    cyan   = { 0.2,  0.75,  1.0   },  -- primary system accent (frames/strips/neutral)
    teal   = { 0.20, 0.95,  0.85  },  -- good / owned / upgraded
    violet = { 0.72, 0.45,  1.0   },  -- PaP / Mega reward tier
    amber  = { 1.0,  0.88,  0.25  },  -- money / value / normal damage
    danger = { 0.90, 0.20,  0.55  },  -- low / empty / boss / lockdown
}

-- The Armory (Mule Kick Mega) makes all buys 10% cheaper. 10% off, floored to a clean
-- multiple of 10 - MUST match the GSC (armory_discounted / _acc_pap_levels keeper).
local function acc_discount(n)
    return math.floor(n * 0.9 / 10) * 10
end

-- Pack-a-Punch tier text (MUST mirror _acc_pap_levels.gsc tier_benefit / tier_repack_cost +
-- ACC_PAP_FIRST_PACK_COST). 3-tier revamp 2026-06-16: the transform ("_up" form) is DEFERRED
-- to tier 2; tier 1 is damage only. (Gold PaP camo removed 2026-06-27.)
local function pap_tier_benefit(tier)
    if tier == 1 then return "more damage" end
    if tier == 2 then return "much more + new form" end
    if tier == 3 then return "max damage" end
    return ""
end
local function pap_tier_cost(tier)
    if tier == 1 then return 5000 end  -- first pack (the machine's own cost; may differ on a sale)
    if tier == 2 then return 7500 end
    if tier == 3 then return 10000 end
    return 0
end

-- Perk card content. Index MUST match _acc_perk_info::perk_card_index, and titles/prices MUST
-- stay in sync with ui/uieditor/widgets/HUD/Mappings/AetheriumPerks.lua (name/cost) - the
-- Aetherium buy prompt displays THAT table for the same machines (PromptPerks.lua).
--   base     = benefits of the BASE perk (shown on the buy card + as the Mega preview's
--              "before"); mega = what the Mega bottle ADDS/UPGRADES (shown when you own
--              base but haven't Mega'd - mode 1). megaFull = the single merged list shown
--              once you OWN the Mega (mode 2): every effective benefit, with Mega values
--              REPLACING the base ones they supersede (no "+50%" AND "+70%" - just "+70%").
local AccPerkCards = {
    -- Bullets MUST be SHORT (<= ~28 chars) or they WRAP and break the card layout (user 2026-06-22,
    -- esp. Double Tap). Vague by design (docs/50): magnitudes hidden, base<Mega via the word ladder.
    [1] = { title = "JUGGER-NOG", price = "4000", megaName = "Ultimate Tank",
            base = { "Take more hits" },
            mega = { "Take even more hits" },
            megaFull = { "Take even more hits" } },
    [2] = { title = "QUICK REVIVE", price = "2500", megaName = "Savior",
            base = { "Revive allies faster", "Health regen starts sooner", "Revive yourself solo" },
            mega = { "Revive even faster", "Regen starts even sooner", "Faster when an ally is down", "Shielded while reviving" },
            megaFull = { "Revive even faster", "Regen starts even sooner", "Revive yourself solo", "Faster when an ally is down", "Shielded while reviving" } },
    [3] = { title = "SPEED COLA", price = "3500", megaName = "Sleight of Hand Expert",
            base = { "Reload faster", "Fix barriers faster" },
            mega = { "Reload even faster" },
            megaFull = { "Reload even faster", "Fix barriers faster" } },
    [4] = { title = "DOUBLE TAP 2.0", price = "3000", megaName = "Gun Slinger",
            base = { "Fires extra bullets", "Shoots faster" },
            mega = { "Extra bullets hit harder" },
            megaFull = { "Fires extra bullets", "Shoots faster", "Extra bullets hit harder" } },
    [5] = { title = "STAMIN-UP", price = "2000", megaName = "The Flash",
            base = { "Sprint longer", "Move faster" },
            mega = { "Move even faster" },
            megaFull = { "Sprint longer", "Move even faster" } },
    [6] = { title = "MULE KICK", price = "2500", megaName = "The Armory",
            base = { "Carry an extra gun" },
            mega = { "More ammo each round", "Cheaper buys" },
            megaFull = { "Carry an extra gun", "More ammo each round", "Cheaper buys" } },
    [7] = { title = "DEADSHOT", price = "3500", megaName = "American Sniper",
            base = { "More headshot damage", "Aims at the head" },
            mega = { "Even more headshot dmg", "Much less recoil" },
            megaFull = { "Even more headshot dmg", "Much less recoil", "Aims at the head" } },
    [8] = { title = "WIDOW'S WINE", price = "4000", megaName = "Spiderman",
            base = { "Grenades trap zombies", "Webbing on melee", "Refills each round" },
            mega = { "Scuttle fast when low", "More spider drops" },
            megaFull = { "Grenades trap zombies", "Webbing on melee", "Scuttle fast when low", "More spider drops" } },
    [9] = { title = "PHD FLOPPER", price = "2500", megaName = "PhD Slider",
            base = { "No fall or blast damage", "Explode when downed" },
            mega = { "Slide to explode", "More explosive damage", "Move faster" },
            megaFull = { "No fall or blast damage", "Slide to explode", "Explode when downed", "More explosive damage", "Move faster" } },
    [10] = { title = "ELECTRIC CHERRY", price = "3000", megaName = "Power Surge",
            base = { "Reload to zap zombies", "Emptier mag = bigger zap" },
            mega = { "Stronger, faster zap", "Shrugs off boss zaps" },
            megaFull = { "Reload to zap zombies", "Emptier mag = bigger zap", "Stronger, faster zap", "Shrugs off boss zaps" } },
    [11] = { title = "PACK-A-PUNCH", price = "",
            base = { "Re-pack to upgrade more:", "T1: more damage",
                     "T2: much more damage", "T3: max damage" } },
}

-- Overclock report card: gun display names by index (MUST match _acc_perk_info::gun_card_index).
-- The kiosk pushes accPerkCard = 44 + gunIdx (the unused range between perk codes 0..43 and the
-- +64 Armory-discount bit), so the card knows the held gun's name; PaP + OC levels come from the
-- accPapTier / accOcTier models (already pushed for the held weapon).
local AccGunNames = {
    [0] = "Five-Seven", [1] = "ASM1", [2] = "Tac-19", [3] = "AK-47", [4] = "AE4",
    [5] = "RW1", [6] = "Paladin HB50", [7] = "PPSH-41", [8] = "Mahem", [9] = "HAMR",
    [10] = "M16", [11] = "AK-74u", [12] = "Olympia", [13] = "Grav", [14] = "M60",
    [15] = "RPD", [16] = "Thundergun", [17] = "Held weapon",
}

-- Exo Suit report card: Data Shard cost to reach each tier (MUST mirror _acc_exo.gsc::exo_cost).
-- Keyed by TARGET tier 1..10 (user 2026-06-24: 10 tiers, LINEAR 4 x tier). The card (code 108 + exoTier)
-- shows the next tier's cost.
local AccExoCosts = { [1] = 4, [2] = 8, [3] = 12, [4] = 16, [5] = 20, [6] = 24, [7] = 28, [8] = 32, [9] = 36, [10] = 40 }

-- Classed widget: the perk/PaP info card. Mirrors zm_building room_manager.lua /
-- challenge_control.lua (InheritFrom + setClass + children + subscribeToModel).
CoD.AccPerkCard = InheritFrom(LUI.UIElement)

function CoD.AccPerkCard.new(HudRef, InstanceRef)
    local self = LUI.UIElement.new()
    self:setClass(CoD.AccPerkCard)
    -- ORIGINAL right-side location (user confirmed this position was fine) with a
    -- SMALLER height. Text is nudged right in NewLine below (first few letters were
    -- starting off the left edge of the card).
    self:setLeftRight(false, true, -394, -22)
    self:setTopBottom(false, false, -140, 140) -- centered, 280 tall (was 336)
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
    Accent.Bg:setRGB(ACC_PAL.cyan[1], ACC_PAL.cyan[2], ACC_PAL.cyan[3])
    Accent.Bg:setAlpha(0.9)
    self:addElement(Accent)

    -- Matching bottom accent strip so the card is framed top+bottom, not a bare box (docs/49).
    local AccentB = CoD.TextWithBg.new(HudRef, InstanceRef)
    AccentB:setLeftRight(true, true, 0, 0)
    AccentB:setTopBottom(false, true, -4, 0)
    AccentB.Text:setText("")
    AccentB.Bg:setRGB(ACC_PAL.cyan[1], ACC_PAL.cyan[2], ACC_PAL.cyan[3])
    AccentB.Bg:setAlpha(0.9)
    self:addElement(AccentB)

    -- Left-anchored text box (challenge_control.lua idiom) - cleaner than a
    -- two-sided anchor when combined with setScale + left alignment.
    local function NewLine(topPx, botPx, scale)
        local t = LUI.UIText.new()
        -- Original left-anchored box, but the left offset bumped 18 -> 44 so the first
        -- few letters no longer start off the left edge of the card. (true = parent-left.)
        t:setLeftRight(true, false, 44, 380)
        t:setTopBottom(true, false, topPx, botPx)
        t:setAlignment(Enum.LUIAlignment.LUI_ALIGNMENT_LEFT)
        t:setScale(scale)
        self:addElement(t)
        return t
    end

    local CardTitle = NewLine(16, 48, 1.0)
    local CardSub   = NewLine(50, 74, 0.9)
    local CardBullets = {}
    for i = 1, ACC_CARD_BULLETS do
        CardBullets[i] = NewLine(84 + (i - 1) * 28, 110 + (i - 1) * 28, 0.85)
    end

    local papTier = 0
    local ocTier = 0
    local cardModel = Engine.GetModel(Engine.GetModelForController(InstanceRef), "accPerkCard")

    local function RenderCard(ModelRef)
        local code = Engine.GetModelValue(ModelRef)
        if not code or code == 0 then
            self:hide()
            return
        end

        -- OVERCLOCK REPORT CARD: code 44..63 = 44 + gunIdx (the unused gap between perk codes 0..43
        -- and the +64 Armory-discount range). Walk up to the kiosk -> full report of the HELD gun:
        -- name + PaP level/benefit + Overclock level/benefits (PaP/OC tiers from the live models).
        -- OC benefit formula mirrors _acc_damage: +5%/tier dmg, +25%/tier glitch, 10%/tier ammo.
        if code >= 44 and code <= 63 then
            CardTitle:setText(AccGunNames[code - 44] or "Held weapon")
            CardTitle:setRGB(0.30, 0.95, 0.85)
            -- PaP info REMOVED from this card (user 2026-06-22): PaP has NO display/indication anywhere.
            CardSub:setText("Overclock v" .. ocTier .. " / 10")
            CardSub:setRGB(0.86, 0.9, 0.95)

            local lines = {}
            if ocTier <= 0 then
                lines[#lines + 1] = "Not overclocked yet"
            else
                -- Vague by design (docs/50): the tier (vN/5) conveys progress; effects show direction only.
                lines[#lines + 1] = "More gun damage"
                lines[#lines + 1] = "More vs glitch zombies"
                lines[#lines + 1] = "Headshot kills give ammo"
            end
            for i = 1, ACC_CARD_BULLETS do
                if lines[i] then
                    CardBullets[i]:setText(lines[i])
                    CardBullets[i]:setRGB(0.55, 0.92, 0.95)
                else
                    CardBullets[i]:setText("")
                end
            end
            self:show()
            return
        end

        -- EXO SUIT REPORT CARD: code 108..127 = 108 + exoTier (above the +64 discount range 64..107).
        -- Walk up to the station -> what the exo DOES + the next tier's cost, so the player knows what
        -- the upgrade buys (the whole point of this card). The exo cancels the trench movement-slow one
        -- layer deeper per tier; costs/benefits mirror _acc_exo.gsc (exo_cost / ACC_EXO_MAX).
        if code >= 108 and code <= 127 then
            local exoTier = code - 108
            CardTitle:setText("EXO SUIT")
            CardTitle:setRGB(0.55, 0.85, 1.0)
            CardSub:setText("Tier " .. exoTier .. " / 10")
            CardSub:setRGB(0.86, 0.9, 0.95)

            -- The 3 exo augments (the BODY counterpart to the gun Overclock's 3). Vague by design (docs/50):
            -- the tier (N/5) + "layer N" show progress; effects show direction only. Exact per-tier values
            -- (resist 5%/tier, melee +30%/tier) live in docs/47 + _acc_exo.gsc / _acc_elites.gsc / _acc_damage.gsc.
            local lines = {}
            if exoTier <= 0 then
                lines[#lines + 1] = "Each tier gives:"
                lines[#lines + 1] = "  Move faster in trenches"
                lines[#lines + 1] = "  Take less damage"
                lines[#lines + 1] = "  Stronger melee"
            else
                -- The abyss only has 5 built layers, so cap the "full speed to layer N" text at 5
                -- (tiers 6-10 keep adding resist + melee; depth past L5 is inert until those layers exist).
                local shownLayer = exoTier
                if shownLayer > 5 then shownLayer = 5 end
                lines[#lines + 1] = "Full speed to layer " .. shownLayer
                lines[#lines + 1] = "Take less damage"
                lines[#lines + 1] = "Stronger melee"
            end
            if exoTier >= 10 then
                lines[#lines + 1] = "MAX - fully upgraded"
            else
                local nextT = exoTier + 1
                lines[#lines + 1] = "Tier " .. nextT .. ": " .. (AccExoCosts[nextT] or 0) .. " Data Shards"
                lines[#lines + 1] = "  Reaches deeper"
            end
            for i = 1, ACC_CARD_BULLETS do
                if lines[i] then
                    CardBullets[i]:setText(lines[i])
                    CardBullets[i]:setRGB(0.6, 0.9, 1.0)
                else
                    CardBullets[i]:setText("")
                end
            end
            self:show()
            return
        end

        -- High bit (+64) = viewer holds The Armory -> show the 10%-off price.
        local discounted = false
        if code >= 64 then
            discounted = true
            code = code - 64
        end
        local idx = math.floor(code / 4)
        local mode = code % 4
        local d = AccPerkCards[idx]
        if not d then
            self:hide()
            return
        end

        local title, sub, bullets, titleCol, bulletCol
        local bulletColsByIndex -- optional per-bullet color overrides (nil = use bulletCol)
        if idx == 11 then
            -- Pack-a-Punch (card index 11 since Electric Cherry took index 10): show ONLY the next tier you'd get.
            title = d.title
            titleCol = { 0.72, 0.45, 1.0 }
            bulletCol = { 0.80, 0.66, 1.0 }
            if papTier >= 3 then
                sub = "Tier 3 / 3 - MAX"
                bullets = { "Max weapon damage" } -- short: avoids wrap at scale 0.85
            else
                local nextTier = papTier + 1
                sub = "Tier " .. papTier .. " / 3 - re-pack to raise"
                local costLine
                if pap_tier_cost(nextTier) > 0 then
                    local pc = pap_tier_cost(nextTier)
                    if discounted then
                        costLine = "Cost: " .. acc_discount(pc) .. " Points (Armory)"
                    else
                        costLine = "Cost: " .. pc .. " Points"
                    end
                else
                    costLine = "Use the Pack-a-Punch machine"
                end
                -- Header / benefit / cost on SEPARATE lines: the combined "Next - Tier
                -- N: <benefit>" string was long enough (esp. tier 1) to wrap into the
                -- cost line below it. One line each = no wrap, no overlap.
                bullets = {
                    "Next: Tier " .. nextTier .. " / 3",
                    pap_tier_benefit(nextTier),
                    costLine
                }
            end
        elseif mode == 1 then
            -- Owns base, not Mega'd yet: preview what the Mega bottle adds.
            title = d.megaName or d.title
            sub = "Mega upgrade: 1 Bottle"
            bullets = d.mega or {}
            titleCol = { 0.96, 0.78, 0.25 }
            bulletCol = { 0.96, 0.84, 0.5 }
        elseif mode == 2 then
            -- Owned + Mega'd: the Mega NAME replaces the perk name as the title, and we
            -- show ONE merged "effective benefits" list (megaFull) - every benefit you
            -- have, but where a Mega stat supersedes a base stat only the Mega value is
            -- listed (e.g. "+70% reload speed" + "Faster barrier repair", never both
            -- "+50%" and "+70%"). Not base stacked over mega - a single curated list.
            -- The whole card stays the yellow Mega color.
            title = "Mega: " .. (d.megaName or d.title)
            sub = ""
            bullets = d.megaFull or d.mega or {}
            titleCol = { 0.96, 0.78, 0.25 }
            bulletCol = { 0.96, 0.84, 0.5 }
        else
            title = d.title
            if d.price ~= "" then
                local p = tonumber(d.price)
                if discounted and p then
                    sub = "Cost: " .. acc_discount(p) .. " Points (Armory)"
                else
                    sub = "Cost: " .. d.price .. " Points"
                end
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
                local c = (bulletColsByIndex and bulletColsByIndex[i]) or bulletCol
                CardBullets[i]:setRGB(c[1], c[2], c[3])
            else
                CardBullets[i]:setText("")
            end
        end

        self:show()
    end

    self:subscribeToModel(cardModel, RenderCard)

    -- PaP tier: update + re-render the card (only matters while the PaP / overclock card is up).
    self:subscribeToModel(Engine.GetModel(Engine.GetModelForController(InstanceRef), "accPapTier"), function(m)
        papTier = Engine.GetModelValue(m) or 0
        RenderCard(cardModel)
    end)

    -- Overclock tier: update + re-render (matters while the overclock report card is up).
    self:subscribeToModel(Engine.GetModel(Engine.GetModelForController(InstanceRef), "accOcTier"), function(m)
        ocTier = Engine.GetModelValue(m) or 0
        RenderCard(cardModel)
    end)

    self:hide()
    return self
end

-- Floating combat text (docs/49). Each "accDmgNum" push (value = dmg*4 + headshot*2 + parity;
-- the server pushes one discrete value per ~0.1s damage window, parity flips so identical
-- numbers re-fire) spawns its OWN number from a POOL: it appears at a scattered point in a small
-- circle near the crosshair, RISES and FADES over 1s, then the slot is reused. So rapid hits
-- stack as separate rising numbers instead of one value overwriting itself. Headshot = teal.
local ACC_DMG_COLOR    = { 1.0, 0.88, 0.25 }   -- normal hit (amber)
local ACC_DMG_COLOR_HS = { 0.20, 0.95, 0.85 }  -- headshot hit (teal)
local ACC_DMG_POOL  = 12     -- max simultaneous numbers (also = #scatter points)
local ACC_DMG_LIFE  = 500    -- ms on screen (rise + fade) (user 2026-06-22: 0.5s)
local ACC_DMG_RISE  = 46     -- px drift up over its life
local ACC_DMG_SCALE    = 0.38   -- normal hit (user 2026-06-22: 15% smaller, was 0.45)
local ACC_DMG_SCALE_HS = 0.48   -- headshot: 25% larger than normal (0.38 * 1.25)
local ACC_DMG_CY     = 0      -- spawn-circle center = DEAD CENTER of screen (user 2026-06-22)
local ACC_DMG_SPREAD = 0.4    -- scatter-circle size multiplier (user 2026-06-22: 20% tighter, was 0.5)
local ACC_DMG_BOXW  = 80     -- half text-box width (for centered text)
-- 12 scatter offsets within a ~55px circle so consecutive numbers don't land on the same spot.
local ACC_DMG_SCATTER = {
    { 0, 0 }, { 30, -16 }, { -26, -22 }, { 10, 28 }, { -36, 6 }, { 38, 12 },
    { -12, -34 }, { 22, 34 }, { -38, -10 }, { 6, -26 }, { 34, -30 }, { -24, 26 },
}
CoD.AccDmgNum = InheritFrom(LUI.UIElement)

function CoD.AccDmgNum.new(HudRef, InstanceRef)
    local self = LUI.UIElement.new()
    self:setClass(CoD.AccDmgNum)
    self:setLeftRight(true, true, 0, 0)   -- full-screen container; children anchor from screen center
    self:setTopBottom(true, true, 0, 0)
    self.id = "AccDmgNum"

    -- Pool of reusable number elements (center-anchored so a spawn just sets its offset).
    local pool = {}
    for i = 1, ACC_DMG_POOL do
        local t = LUI.UIText.new()
        t:setAlignment(Enum.LUIAlignment.LUI_ALIGNMENT_CENTER)
        t:setScale(ACC_DMG_SCALE)
        t:setRGB(ACC_DMG_COLOR[1], ACC_DMG_COLOR[2], ACC_DMG_COLOR[3])
        t:setLeftRight(false, false, -ACC_DMG_BOXW, ACC_DMG_BOXW)
        t:setTopBottom(false, false, ACC_DMG_CY - 17, ACC_DMG_CY + 17)
        t:setAlpha(0)
        self:addElement(t)
        pool[i] = t
    end
    local nextIdx = 1

    local function spawn(dmg, hs)
        local t = pool[nextIdx]
        local p = ACC_DMG_SCATTER[nextIdx]
        nextIdx = (nextIdx % ACC_DMG_POOL) + 1
        local c  = hs and ACC_DMG_COLOR_HS or ACC_DMG_COLOR
        local sc = hs and ACC_DMG_SCALE_HS or ACC_DMG_SCALE   -- headshots 25% bigger
        local cx = p[1] * ACC_DMG_SPREAD              -- circle scaled by spread, centered on screen center
        local cy = ACC_DMG_CY + p[2] * ACC_DMG_SPREAD
        t:completeAnimation()
        t:setRGB(c[1], c[2], c[3])
        t:setText(tostring(dmg))
        t:setScale(sc)
        t:setLeftRight(false, false, cx - ACC_DMG_BOXW, cx + ACC_DMG_BOXW)
        t:setTopBottom(false, false, cy - 17, cy + 17)       -- start: box centered on the point
        t:setAlpha(1.0)
        t:beginAnimation("keyframe", ACC_DMG_LIFE, false, false, CoD.TweenType.Linear)
        t:setTopBottom(false, false, cy - 17 - ACC_DMG_RISE, cy + 17 - ACC_DMG_RISE)  -- rise
        t:setAlpha(0)                                         -- and fade
    end

    local function OnDmg(ModelRef)
        local v = Engine.GetModelValue(ModelRef) or 0
        if v == 0 then return end   -- queue: each number self-fades; the hide signal is a no-op now
        -- Decode dmg*4 + headshot*2 + parity (parity = bit0 re-fires identical numbers).
        local dmg = math.floor(v / 4)
        if dmg <= 0 then return end
        local hs = math.floor(v / 2) % 2 >= 1
        spawn(dmg, hs)
    end

    self:subscribeToModel(Engine.GetModel(Engine.GetModelForController(InstanceRef), "accDmgNum"), OnDmg)
    return self
end

-- TOUCHPOINT 2 - Mega perk-icon ROW (Ronan's Cyberpunk Shaders). CoD.AccPerkBar.
-- Our own perk bar (the stock bar can't show Mega state and its perk materials are
-- not loadable in a usermap). One cyberpunk icon per OWNED perk, packed left-to-right,
-- whose ART encodes Mega state:
--     RED icon = base perk  |  TEAL icon = Mega'd  |  (not owned) = hidden
-- Driven by TWO clientuimodel bitmasks the server pushes (_acc_lui.gsc
-- perk_state_watch): "accOwnedMask" (bit i = owns the perk at bar-bit i) and
-- "accMegaMask" (bit i = that perk is Mega'd), bar-bit order from perk_state_watch
-- (bits 0..8 = the 9 perks; PhD Flopper at bit 8). setImage(RegisterImage(name)) is the plain-image path
-- (countryside PerkImage idiom) - no custom material/techset, so it sidesteps the
-- geometry-material shader-compile blocker (docs/29 §14). Images:
-- i_acc_perk_<perk>_{base,mega} (source_data/acc_perk_shaders.gdt, zone `image,`). docs/28.

-- Lua 5.1 / HavokScript has no bitwise operators - test bit i arithmetically.
local function acc_bit_is_set(mask, i)
    return math.floor(mask / (2 ^ i)) % 2 >= 1
end

-- Round-progress ring color: teal (full) -> magenta/red (empty). t in 0..1 = emptiness
-- (0 = round full, 1 = round empty). Used by CoD.AccRoundRing. docs/42.
local ACC_RING_FULL  = { 0.25, 0.85, 0.80 }   -- teal/cyan glow
local ACC_RING_EMPTY = { 0.90, 0.20, 0.55 }   -- magenta/red
local function acc_ring_color(t)
    if t < 0 then t = 0 elseif t > 1 then t = 1 end
    return ACC_RING_FULL[1] + (ACC_RING_EMPTY[1] - ACC_RING_FULL[1]) * t,
           ACC_RING_FULL[2] + (ACC_RING_EMPTY[2] - ACC_RING_FULL[2]) * t,
           ACC_RING_FULL[3] + (ACC_RING_EMPTY[3] - ACC_RING_FULL[3]) * t
end

-- bar-bit index -> icon base name (base=red / mega=teal). MUST match the bit order
-- in _acc_lui.gsc perk_state_watch. All 9 perks render; PhD Flopper is bit 8
-- (Ronan's exo_flopper icon, i_acc_perk_phd_{base,mega}).
local ACC_PERK_ICONS = {
    [0] = "jugg", [1] = "revive", [2] = "speed", [3] = "doubletap",
    [4] = "staminup", [5] = "mule", [6] = "deadshot", [7] = "widows",
    [8] = "phd", [9] = "cherry",
}
local ACC_PERK_COUNT = 10

CoD.AccPerkBar = InheritFrom(LUI.UIElement)

function CoD.AccPerkBar.new(HudRef, InstanceRef)
    local self = LUI.UIElement.new()
    self:setClass(CoD.AccPerkBar)
    self.id = "AccPerkBar"
    self:setLeftRight(true, true, 0, 0)
    self:setTopBottom(true, true, 0, 0)

    -- Bottom-left row. These 4 numbers position the whole bar - tune in-game.
    local SIZE = 44     -- icon width/height (virtual px)
    local PITCH = 50    -- spacing >= SIZE so icons no longer overlap (was 38 -> 48; +2 gap, user 2026-07-15)
    local START_X = 106 -- left offset of the first icon (was 96; +10 right so it clears the round
                        -- counter at bottom-left, user 2026-06-17)
    local BOTTOM = 26   -- gap from the bottom edge

    -- One UIImage per perk; hidden until owned, repositioned on each ownership change.
    local icons = {}
    for i = 0, ACC_PERK_COUNT - 1 do
        local img = LUI.UIImage.new()
        img:setTopBottom(false, true, -(BOTTOM + SIZE), -BOTTOM)
        img:setImage(RegisterImage("i_acc_perk_" .. ACC_PERK_ICONS[i] .. "_base"))
        img:hide()
        self:addElement(img)
        icons[i] = { img = img, art = nil }
    end

    local ownedMask = 0
    local megaMask = 0
    local order = {}    -- perk indices in ACQUISITION order (stable slots; new perks append RIGHT)

    -- STACK owned perks in the order they were ACQUIRED (user 2026-06-17): the first perk you buy
    -- keeps the leftmost slot, and each new perk appears to its RIGHT - NOT re-sorted by perk type
    -- (which used to put the newest perk on the left). red=base / teal=Mega icon art.
    local function Render()
        -- Rebuild `order`: keep still-owned entries first (preserves each perk's existing slot),
        -- then append any newly-owned perks (bit order only breaks ties if two are gained in one tick).
        local newOrder = {}
        local seen = {}
        for _, i in ipairs(order) do
            if acc_bit_is_set(ownedMask, i) and not seen[i] then
                newOrder[#newOrder + 1] = i
                seen[i] = true
            end
        end
        for i = 0, ACC_PERK_COUNT - 1 do
            if acc_bit_is_set(ownedMask, i) and not seen[i] then
                newOrder[#newOrder + 1] = i
                seen[i] = true
            end
        end
        order = newOrder

        for i = 0, ACC_PERK_COUNT - 1 do icons[i].img:hide() end
        for slot = 1, #order do
            local i = order[slot]
            local rec = icons[i]
            local x = START_X + (slot - 1) * PITCH
            rec.img:setLeftRight(true, false, x, x + SIZE)
            local wantArt = acc_bit_is_set(megaMask, i) and "mega" or "base"
            if wantArt ~= rec.art then
                rec.art = wantArt
                rec.img:setImage(RegisterImage("i_acc_perk_" .. ACC_PERK_ICONS[i] .. "_" .. wantArt))
            end
            rec.img:show()
        end
    end

    self:subscribeToModel(Engine.GetModel(Engine.GetModelForController(InstanceRef), "accOwnedMask"), function(m)
        ownedMask = Engine.GetModelValue(m) or 0
        Render()
    end)
    self:subscribeToModel(Engine.GetModel(Engine.GetModelForController(InstanceRef), "accMegaMask"), function(m)
        megaMask = Engine.GetModelValue(m) or 0
        Render()
    end)

    return self
end

-- TOUCHPOINT 3 - Power-up active icons (Ronan's Cyberpunk Shaders). CoD.AccPowerupBar.
-- Shows a cyberpunk icon while each power-up is active: Insta-Kill / Double Points / Fire
-- Sale. Driven by the "accPowerupMask" clientuimodel bitmask the server pushes
-- (_acc_lui.gsc powerup_state_watch): bit 0 = insta-kill, bit 1 = double points, bit 2 =
-- fire sale. Same setImage(RegisterImage(...)) plain-image path as the perk bar (no custom
-- material - sidesteps the geometry-material shader-compile blocker, docs/29 §14). Images:
-- i_acc_powerup_{instakill,double,sale} (source_data/acc_perk_shaders.gdt, zone `image,`).
-- Dynamic bottom-center list (re-centers as it grows); each icon shows only while its bit is set.
-- Bits 0-2 are the TIMED power-ups (shown while active); bits 3-6 are the INSTANT power-ups Nuke /
-- Max Ammo / Carpenter / Random Perk, which the server flashes for 3s on pickup (_acc_lui pickup-flash
-- watchers). Same rail. The stock power-up active icons for these are suppressed server-side
-- (_acc_lui::suppress_stock_powerup_hud) so ONLY these show.
local ACC_POWERUP_ICONS = {
    [0] = "instakill", [1] = "double", [2] = "sale", [3] = "nuke", [4] = "maxammo",
    [5] = "carpenter", [6] = "randomperk",
}
local ACC_POWERUP_COUNT = 7

CoD.AccPowerupBar = InheritFrom(LUI.UIElement)

function CoD.AccPowerupBar.new(HudRef, InstanceRef)
    local self = LUI.UIElement.new()
    self:setClass(CoD.AccPowerupBar)
    self.id = "AccPowerupBar"
    self:setLeftRight(true, true, 0, 0)
    self:setTopBottom(true, true, 0, 0)

    -- Bottom-center DYNAMIC list (user 2026-06-17): NOT fixed per-powerup slots - only the ACTIVE
    -- icons show, packed left-to-right and CENTERED AS A GROUP (the stock-powerup-HUD feel). The row
    -- re-centers as it grows/shrinks, so a lone icon is dead-center and e.g. the 3rd of 5 active lands
    -- in the exact middle. Bottom-anchored; clears the perk bar (bottom-left) + ammo/PaP (bottom-right).
    local SIZE = 48      -- icon width/height (virtual px)
    local PITCH = 58     -- spacing between adjacent active icons
    local BOTTOM = 58    -- gap from the bottom edge; lowered from 92 (user 2026-06-17); tune in-game

    -- One UIImage per powerup; created bottom-anchored. Horizontal position is assigned per-render
    -- (depends on how many are active), so we don't fix it here.
    local icons = {}
    for i = 0, ACC_POWERUP_COUNT - 1 do
        local img = LUI.UIImage.new()
        img:setTopBottom(false, true, -(BOTTOM + SIZE), -BOTTOM)
        img:setImage(RegisterImage("i_acc_powerup_" .. ACC_POWERUP_ICONS[i]))
        img:hide()
        self:addElement(img)
        icons[i] = img
    end

    -- Show only active icons, packed in bit order and centered as a group. With K active, the j-th
    -- (0-based) sits (j - (K-1)/2) * PITCH from screen center.
    local function Render(mask)
        local active = {}
        for i = 0, ACC_POWERUP_COUNT - 1 do
            if acc_bit_is_set(mask, i) then active[#active + 1] = i end
        end
        local K = #active
        for i = 0, ACC_POWERUP_COUNT - 1 do icons[i]:hide() end
        for j = 1, K do
            local i = active[j]
            local cx = ((j - 1) - (K - 1) / 2) * PITCH
            icons[i]:setLeftRight(false, false, cx - SIZE / 2, cx + SIZE / 2)
            icons[i]:show()
        end
    end

    self:subscribeToModel(Engine.GetModel(Engine.GetModelForController(InstanceRef), "accPowerupMask"), function(m)
        Render(Engine.GetModelValue(m) or 0)
    end)

    return self
end

-- RETIRED (gun-badge unification, 2026-07-08): CoD.AccPapTierIcon / CoD.AccOcTierText /
-- CoD.AccMuleTag below are no longer instantiated - the unified CoD.AccGunBadgeRow (next
-- touchpoint after them) draws PaP/OC/MULE/TURBO as ONE chip row under the ammo readout.
-- Classes kept as the restore path (re-add their 3 registrations in createMenu).
--
-- TOUCHPOINT 4 - Pack-a-Punch tier icon (Ronan teal hex shields, roman I/II/III). CoD.AccPapTierIcon.
-- Shows the HELD weapon's current PaP tier as ONE small icon centered over the gadget HUD circle
-- (bottom-right), replacing the old "PaP TIER x/3" font string (user 2026-06-16). Driven by the
-- "accPapTier" clientuimodel (0..3; _acc_pap_levels::pap_hud_loop pushes the held gun's tier on
-- change). 0 = hidden. Same setImage(RegisterImage(...)) plain-image path as the perk/powerup bars
-- (no custom material - sidesteps the geometry-material shader-compile blocker, docs/29 §14).
-- Images: i_acc_pap_tier{1,2,3} (source_data/acc_perk_shaders.gdt, zone `image,`).
local ACC_PAP_TIER_MAX = 3

CoD.AccPapTierIcon = InheritFrom(LUI.UIElement)

function CoD.AccPapTierIcon.new(HudRef, InstanceRef)
    local self = LUI.UIElement.new()
    self:setClass(CoD.AccPapTierIcon)
    self.id = "AccPapTierIcon"
    self:setLeftRight(true, true, 0, 0)
    self:setTopBottom(true, true, 0, 0)

    -- Small fixed-size icon over the gadget HUD circle, anchored to the BOTTOM-RIGHT corner. RIGHT =
    -- gap from the right edge to the icon's right side; BOTTOM = gap from the bottom edge to its
    -- bottom side; the icon extends SIZE left/up from there. Uses the proven far-edge fixed-box idiom
    -- (false,true + NEGATIVE offsets) - same as the perk/powerup bars. (NOTE: setLeftRight(true,true,..)
    -- is STRETCH/fill mode, which is what made this span the whole screen before - do NOT use it for a
    -- fixed box.) TUNE RIGHT/BOTTOM in-game to center it on the gadget.
    -- Relocated 2026-06-26 to sit as a STATUS CHIP in the new combat device's header row (top-left of
    -- the AccAmmoBlock plate at RIGHT 44 / BOTTOM 50 / W 216 / H 100), next to the Overclock vN chip.
    -- Registered AFTER the ammo block (see createMenu) so it draws ON TOP of the translucent plate.
    -- Screenshot tune #2 2026-07-03 (user: "I don't want pap label - just the icon, level;
    -- it was going out of bounds of the section"): NO text label - the tier shield alone,
    -- pulled LEFT into the loadout section where the old label sat, with the "OC vN" row
    -- (AccOcTierText) stacked directly below and right-aligned to the same edge. TUNE IN-GAME.
    local SIZE = 26       -- icon width/height (virtual px)
    local RIGHT = 52      -- tune #5 (user: "pap tier icon over 6 points"; +4 then +2 left 2026-07-06) - icon x 1202..1228
    local BOTTOM = 100    -- icon y 594..620

    local icons = {}
    for t = 1, ACC_PAP_TIER_MAX do
        local img = LUI.UIImage.new()
        img:setLeftRight(false, true, -(RIGHT + SIZE), -RIGHT)
        img:setTopBottom(false, true, -(BOTTOM + SIZE), -BOTTOM)
        img:setImage(RegisterImage("i_acc_pap_tier" .. t))
        img:hide()
        self:addElement(img)
        icons[t] = img
    end

    -- Show only the icon matching the current tier (1..3); hide all at tier 0.
    local function Render(tier)
        for t = 1, ACC_PAP_TIER_MAX do
            if t == tier then icons[t]:show() else icons[t]:hide() end
        end
    end

    self:subscribeToModel(Engine.GetModel(Engine.GetModelForController(InstanceRef), "accPapTier"), function(m)
        Render(Engine.GetModelValue(m) or 0)
    end)

    return self
end

-- TOUCHPOINT 4b - Cyberware Overclock tier text ("v1".."v5"). CoD.AccOcTierText. Shows the HELD
-- weapon's current Overclock tier as small teal text near the gun name (bottom-right, just ABOVE the
-- PaP tier icon, so OC + PaP stack). Driven by the "accOcTier" clientuimodel (0..5;
-- _acc_overclocks::oc_hud_loop pushes the held gun's tier on change; 0 = hidden). Plain LUI.UIText -
-- same render-safe path as CoD.AccDmgNum (no custom material/font). (accOcTier reuses the dead
-- accLuiTest clientfield slot - no new field, no clientfield-pool growth.)
local ACC_OC_COLOR = { 0.20, 0.95, 0.85 }   -- cyber teal

CoD.AccOcTierText = InheritFrom(LUI.UIElement)

function CoD.AccOcTierText.new(HudRef, InstanceRef)
    local self = LUI.UIElement.new()
    self:setClass(CoD.AccOcTierText)
    self.id = "AccOcTierText"

    -- Fixed box anchored BOTTOM-RIGHT (far-edge idiom: false,true + negative offsets), just above the
    -- PaP tier icon (RIGHT 67 / BOTTOM 82). Tune RIGHT/BOTTOM in-game to sit it by the weapon name.
    -- Relocated 2026-06-26: the "vN" Overclock chip sits in the combat device's header row, just to the
    -- RIGHT of the PaP chip (RIGHT 228) and LEFT of the weapon name. Registered after the ammo block so
    -- it draws on top of the plate.
    -- Screenshot tune #2 2026-07-03 (user: "do OC v3, don't put OVERCLOCK - the long text went
    -- out of bounds"): short "OC vN", right-aligned under the PaP shield, same right edge.
    local W = 80
    local H = 22
    local RIGHT = 47     -- tune #5 (user: "overclock text over 3 points"; +4 left 2026-07-06) - text right edge x 1233
    local BOTTOM = 74    -- y 624..646, just under the PaP row (its BOTTOM = 100)
    self:setLeftRight(false, true, -(RIGHT + W), -RIGHT)
    self:setTopBottom(false, true, -(BOTTOM + H), -BOTTOM)

    -- Label + value on one line ("OVERCLOCK" dim label baked into the string; the vN stays teal).
    local Txt = LUI.UIText.new()
    Txt:setLeftRight(true, true, 0, 0)
    Txt:setTopBottom(true, true, 0, 0)
    Txt:setAlignment(Enum.LUIAlignment.LUI_ALIGNMENT_RIGHT)
    Txt:setScale(0.62)
    Txt:setRGB(ACC_OC_COLOR[1], ACC_OC_COLOR[2], ACC_OC_COLOR[3])
    Txt:setText("")
    self:addElement(Txt)
    self.Txt = Txt

    self:subscribeToModel(Engine.GetModel(Engine.GetModelForController(InstanceRef), "accOcTier"), function(m)
        local t = Engine.GetModelValue(m) or 0
        if t > 0 then
            self.Txt:setText("OC v" .. t)
        else
            self.Txt:setText("")
        end
    end)

    return self
end

-- TOUCHPOINT 4c - Mule Kick at-risk gun tag. CoD.AccMuleTag. An amber "MULE GUN" chip shown while
-- the HELD weapon is the gun Mule Kick removes on a down (the LAST qualifying primary - stock
-- recomputes at loss time; _zm_aetherium_hud::player_mule_watch replicates the filter server-side
-- and drives the "acc_mule" toplayer clientfield -> "acc_mule" UI model, the same escape-hatch
-- bridge as acc_shards because the clientuimodel pool is FULL, docs/42). Lets the player cycle
-- that slot deliberately instead of losing a gun blind (user 2026-07-06).
CoD.AccMuleTag = InheritFrom(LUI.UIElement)

function CoD.AccMuleTag.new(HudRef, InstanceRef)
    local self = LUI.UIElement.new()
    self:setClass(CoD.AccMuleTag)
    self.id = "AccMuleTag"

    -- Right-aligned to the PaP/OC chip column (right edge x ~1233), one row ABOVE the ammo plate
    -- (plate top y 570) so the crowded bottom-right corner stays untouched. y 546..568.
    local W = 110
    local H = 22
    local RIGHT = 47
    local BOTTOM = 152
    self:setLeftRight(false, true, -(RIGHT + W), -RIGHT)
    self:setTopBottom(false, true, -(BOTTOM + H), -BOTTOM)

    local Txt = LUI.UIText.new()
    Txt:setLeftRight(true, true, 0, 0)
    Txt:setTopBottom(true, true, 0, 0)
    Txt:setAlignment(Enum.LUIAlignment.LUI_ALIGNMENT_RIGHT)
    Txt:setScale(0.62)
    Txt:setRGB(0.95, 0.62, 0.22)   -- Mule Kick amber (the Mega-badge palette's Mule colour)
    Txt:setText("")
    self:addElement(Txt)
    self.Txt = Txt

    self:subscribeToModel(Engine.GetModel(Engine.GetModelForController(InstanceRef), "acc_mule"), function(m)
        local v = Engine.GetModelValue(m) or 0
        if v == 1 then
            self.Txt:setText("MULE GUN")
        else
            self.Txt:setText("")
        end
    end)

    return self
end

-- TOUCHPOINT 4d - GUN BADGE ROW (2026-07-08, user: "unify the gun badges - a row under the gun's
-- ammo, start from the right and add to the left"). CoD.AccGunBadgeRow. ONE row of uniform chips
-- under the Aetherium ammo readout showing the HELD weapon's enhancements; the RIGHTMOST chip is
-- badge priority 1 and further badges stack LEFT (toward screen center only as needed). Replaces
-- the three scattered one-offs (AccPapTierIcon / AccOcTierText / AccMuleTag, RETIRED above).
--
-- DATA (two lanes, one row):
--   * TIER badges (an int per badge) ride their EXISTING clientuimodels - "accPapTier" (0..3,
--     _acc_pap_levels::pap_hud_loop) and "accOcTier" (0..10, _acc_overclocks::oc_hud_loop). Those
--     fields must keep flowing anyway (the PaP/OC report cards read the same models), so the row
--     just re-consumes them - NO clientuimodel pool growth (the pool is FULL, docs/42).
--   * FLAG badges (on/off) share the ONE "acc_badges" toplayer->uimodel bitmask
--     (_zm_aetherium_hud::player_gun_badge_watch; bit 0 MULE, bit 1 TURBO, bit 2 NUKE, bit 3 BRZ,
--     2 spare bits).
--
-- TO ADD A BADGE: one entry in ACC_GUN_BADGES below (+ for a flag, OR its bit into the mask in
-- player_gun_badge_watch). Chips auto-pack right-to-left; no per-badge positioning ever again.
--
-- GEOMETRY (virtual 1280x720, from AetheriumLoadout.lua): weapon name y 568..585, mag count
-- y 605..624, reserve count x 968..1057 / y 629..638 -> the row sits at y 644..676 with its right
-- edge at x 1061, flush under the reserve line. CAVEAT: the AAT ammo-mod icon (when an AAT is
-- rolled) occupies x 1037..1061 / y 641..665 - if they collide in-game, raise BOTTOM or drop
-- RIGHT_EDGE to ~250. TUNE IN-GAME (screenshot pass, like every chip before it).
--
-- PENNANT ART (user PNGs 2026-07-08): every live badge is a 5:7 pennant card with its own baked
-- background (i_acc_* images below), so icon chips draw FULL-BLEED with NO plate. Masters are
-- 400x560; shipped textures are 128x128 STRETCHED (single HQ bicubic pass, the proven icon-rail
-- recipe - noMipMaps like every HUD icon), and the quad below is 31x43 = true 5:7, so the GPU
-- un-stretches them back to the exact source aspect. Text chips (label defs) keep the navy plate.
-- Size passes (user 2026-07-08, "make the badges bigger, keep the spacing"): 23x32 -> 31x43 (+35%)
-- -> 34x47 (+10% more). Same ~5:7 aspect; GAP and the row's RIGHT edge untouched, and the row grows
-- DOWNWARD (top edge held at y 644) so the approved distance to the ammo readout never changes -
-- BOTTOM is recomputed each pass as 720 - (644 + H) so the top stays put while H grows.
local ACC_GUN_BADGE_H      = 47    -- uniform chip height (32 -> 43 +35% -> 47 +10%)
local ACC_GUN_BADGE_GAP    = 6     -- horizontal gap between chips (KEEP - user-approved spacing)
local ACC_GUN_BADGE_RIGHT  = 219   -- gap from screen right to the row's right edge (x 1061)
local ACC_GUN_BADGE_BOTTOM = 29    -- gap from screen bottom to the row's bottom edge (y 691; top y 644 held as H grows)

-- Badge registry, PRIORITY order: [1] renders RIGHTMOST, later entries stack left. Fields:
--   model  - UI model driving the badge ("accPapTier" / "accOcTier" / "acc_badges")
--   kind   - "tier" (value = the model int, 0 hides) | "flag" (bit N of the acc_badges mask)
--   w      - chip width (fixed per badge so the row packs deterministically; 34 = ~5:7 of H 47)
--   icon   - image per VALUE (tier v -> icon[v], clamped to last; flags show icon[1]), full-bleed
--   label  - text chip fallback (string, or fn(value)); gets the navy plate + `color` RGB
local ACC_GUN_BADGES = {
    { id = "pap",   model = "accPapTier", kind = "tier", w = 34,
      icon = { "i_acc_pap_tier1", "i_acc_pap_tier2", "i_acc_pap_tier3" } },
    { id = "oc",    model = "accOcTier",  kind = "tier", w = 34,
      icon = { "i_acc_oc_tier1", "i_acc_oc_tier2", "i_acc_oc_tier3", "i_acc_oc_tier4",
               "i_acc_oc_tier5", "i_acc_oc_tier6", "i_acc_oc_tier7", "i_acc_oc_tier8",
               "i_acc_oc_tier9", "i_acc_oc_tier10" } },
    { id = "mule",  model = "acc_badges", kind = "flag", bit = 0, w = 34,
      icon = { "i_acc_badge_mule" } },
    { id = "turbo", model = "acc_badges", kind = "flag", bit = 1, w = 34,
      icon = { "i_acc_badge_turbo" } },
    -- PLASMA (Plasma Generator, acc_badges bit 2): shows while implanted AND the held gun is an energy
    -- weapon (_acc_gun_badges::pred_plasma = acc_damage::is_energy_weapon, the +10% energy buff's list).
    -- The ENERGY half of the old Nuclear item. Real art landed 2026-07-15 (cyber_city_final (1).zip
    -- FINAL v6, plasma_energy.png -> i_acc_badge_plasma).
    { id = "plasma", model = "acc_badges", kind = "flag", bit = 2, w = 34,
      icon = { "i_acc_badge_plasma" } },
    -- BRZ (Berzerker, acc_badges bit 3): shows while the implant is in AND the held weapon is one it
    -- speeds up (Leviathan Axe / Action Figure - _acc_gun_badges::pred_berzerker, same name tests as
    -- the damage side's berzerker_melee_weapon; knife-bash surface deliberately not a trigger).
    -- Art landed 2026-07-11 (user's badges_17_enhanced_v3.zip, bezerker.png -> i_acc_badge_berzerker).
    { id = "brz",   model = "acc_badges", kind = "flag", bit = 3, w = 34,
      icon = { "i_acc_badge_berzerker" } },
    -- HICAL (High Caliber Rounds, acc_badges bit 4): shows while the implant is in AND the held weapon is a
    -- bullet gun it buffs (_acc_gun_badges::pred_high_caliber = acc_damage::weapon_is_bullet_gun, mirroring
    -- the +25% damage gate). Real art landed 2026-07-15 (cyber_city_final (1).zip FINAL v6,
    -- high_caliber_round.png -> i_acc_badge_high_caliber).
    { id = "hical", model = "acc_badges", kind = "flag", bit = 4, w = 34,
      icon = { "i_acc_badge_high_caliber" } },
    -- WARHD (Warhead Bomber, acc_badges bit 5): shows while implanted AND the held gun is an explosive
    -- weapon (_acc_gun_badges::pred_warhead = acc_damage::weapon_is_explosive_gun - launchers + bows). The
    -- EXPLOSIVE half of the old Nuclear item. Real art landed 2026-07-15 (cyber_city_final (1).zip FINAL
    -- v6, warhead_bomber.png -> i_acc_badge_warhead). Bit 5 is the LAST bit of the 6-bit acc_badges
    -- clientfield - a 7th badge needs a widen.
    { id = "warhead", model = "acc_badges", kind = "flag", bit = 5, w = 34,
      icon = { "i_acc_badge_warhead" } },
}

CoD.AccGunBadgeRow = InheritFrom(LUI.UIElement)

function CoD.AccGunBadgeRow.new(HudRef, InstanceRef)
    local self = LUI.UIElement.new()
    self:setClass(CoD.AccGunBadgeRow)
    self.id = "AccGunBadgeRow"
    self:setLeftRight(true, true, 0, 0)
    self:setTopBottom(true, true, 0, 0)

    -- Build every chip ONCE (hidden). Icon chips = FULL-BLEED pennant art (the PNGs carry their
    -- own card background, so NO plate - a rectangle behind the pointed pennant would show at the
    -- notch). Text chips (future label defs) = navy glass plate (CoD.TextWithBg.Bg, docs/29 §14)
    -- + centered label. Horizontal anchors are re-set by Layout() as badges come and go.
    local chips = {}
    for i = 1, #ACC_GUN_BADGES do
        local def = ACC_GUN_BADGES[i]
        local chip = LUI.UIElement.new()
        chip:setTopBottom(false, true, -(ACC_GUN_BADGE_BOTTOM + ACC_GUN_BADGE_H), -ACC_GUN_BADGE_BOTTOM)
        chip:setLeftRight(false, true, -(ACC_GUN_BADGE_RIGHT + def.w), -ACC_GUN_BADGE_RIGHT)

        if def.icon then
            -- One pre-registered image per VALUE, show exactly one (AccPapTierIcon idiom). The
            -- image fills the chip box (31x43 = true 5:7 of the stretched 128x128 texture).
            local imgs = {}
            for t = 1, #def.icon do
                local img = LUI.UIImage.new()
                img:setLeftRight(true, true, 0, 0)
                img:setTopBottom(true, true, 0, 0)
                img:setImage(RegisterImage(def.icon[t]))
                img:hide()
                chip:addElement(img)
                imgs[t] = img
            end
            chip.imgs = imgs
        else
            local Plate = CoD.TextWithBg.new(HudRef, InstanceRef)
            Plate.Text:setText("")
            Plate.Bg:setRGB(ACC_PAL.glass[1], ACC_PAL.glass[2], ACC_PAL.glass[3])
            Plate.Bg:setAlpha(0.55)
            Plate:setLeftRight(true, true, 0, 0)
            Plate:setTopBottom(true, true, 0, 0)
            chip:addElement(Plate)

            local txt = LUI.UIText.new()
            txt:setLeftRight(true, true, 0, 0)
            txt:setTopBottom(true, true, 2, -2)
            txt:setAlignment(Enum.LUIAlignment.LUI_ALIGNMENT_CENTER)
            txt:setScale(0.62)
            txt:setRGB(def.color[1], def.color[2], def.color[3])
            txt:setText("")
            chip:addElement(txt)
            chip.txt = txt
        end

        chip:hide()
        self:addElement(chip)
        chips[i] = chip
    end

    -- Live value per badge (tier int / flag 0-1), written by the model subscriptions below.
    local values = {}
    for i = 1, #ACC_GUN_BADGES do values[i] = 0 end

    -- Pack every VISIBLE chip right-to-left from the row's right edge; hide the rest. Re-anchoring
    -- on each change keeps the row gap-free when a middle badge disappears (e.g. swap off the gun).
    local function Layout()
        local rightEdge = ACC_GUN_BADGE_RIGHT
        for i = 1, #ACC_GUN_BADGES do
            local def = ACC_GUN_BADGES[i]
            local v = values[i]
            if v > 0 then
                local chip = chips[i]
                chip:setLeftRight(false, true, -(rightEdge + def.w), -rightEdge)
                if chip.imgs then
                    local t = v
                    if t > #chip.imgs then t = #chip.imgs end
                    for k = 1, #chip.imgs do
                        if k == t then chip.imgs[k]:show() else chip.imgs[k]:hide() end
                    end
                elseif chip.txt then
                    if type(def.label) == "function" then
                        chip.txt:setText(def.label(v))
                    else
                        chip.txt:setText(def.label)
                    end
                end
                chip:show()
                rightEdge = rightEdge + def.w + ACC_GUN_BADGE_GAP
            else
                chips[i]:hide()
            end
        end
    end

    -- ONE subscription per distinct model; on change, refresh every badge riding that model
    -- (flags decode their bit via acc_bit_is_set - Lua 5.1/HavokScript has no bitwise ops).
    --
    -- ACCESSOR CHOICE (bugfix 2026-07-08, user "turbocharger badge never showed"): a TOPLAYER-scoped
    -- field (acc_badges) has NO UI-model node until its server bridge's createuimodel fires on the
    -- FIRST change - so Engine.GetModel subscribes to a node that never gets populated and the callback
    -- never fires (the MULE/TURBO flags were dead). Engine.CreateModel makes the SAME node the bridge
    -- later writes, so the subscription catches it - the exact pattern the working currency chips use
    -- (AetheriumPlayerInfo.lua acc_shards/acc_mb/acc_exo/acc_maxhp). The clientuimodel-scope tier
    -- fields (accPapTier/accOcTier) ARE auto-created, so GetModel works for them (proven by the old
    -- AccPapTierIcon/AccOcTierText) - but CreateModel is idempotent (returns the existing node), so we
    -- use it for BOTH lanes: correct for toplayer, harmless for clientuimodel, one code path.
    local controllerModel = Engine.GetModelForController(InstanceRef)
    local subscribed = {}
    for i = 1, #ACC_GUN_BADGES do
        local modelName = ACC_GUN_BADGES[i].model
        if not subscribed[modelName] then
            subscribed[modelName] = true
            self:subscribeToModel(Engine.CreateModel(controllerModel, modelName), function(m)
                local raw = Engine.GetModelValue(m) or 0
                for j = 1, #ACC_GUN_BADGES do
                    local d = ACC_GUN_BADGES[j]
                    if d.model == modelName then
                        if d.kind == "flag" then
                            values[j] = (acc_bit_is_set(raw, d.bit) and 1 or 0)
                        else
                            values[j] = raw
                        end
                    end
                end
                Layout()
            end)
        end
    end

    return self
end

-- TOUCHPOINT 4e - IMPLANT SLOT CARDS (2026-07-12, user: "replace our implant system with pngs -
-- place the emblem png over the implant png to show it's enabled"). CoD.AccImplantRow. Three
-- always-on slot cards on the left HUD (art pack cyber_city_implant_hud, v4 "compact" set): each
-- card (962x176 bar, big readable "IMPLANT N" title only - the old tiny "CYBERNETIC AUGMENT" sub-
-- line was dropped because it minified below readability, docs/19) gets one glyph-only emblem
-- overlay UIImage; when the slot's item id is non-zero its 256x256 glyph draws over the bar's right
-- window (v4 README: glyph = 92% of bar height, x-center at 90.1% of bar width). A 4th HOLDING bar
-- = carried-but-not-benched.
--
-- DATA: the EXISTING 16-bit "acc_implants" toplayer->uimodel nibble pack (bits 0-3 Slot 1 /
-- 4-7 Slot 2 / 8-11 Slot 3 / 12-15 carried; _acc_boss_items::push_implants_clientfield) - the
-- same wire the pause-menu panel reads. NO new clientfield/model/hudelem anywhere; this widget
-- REPLACED the GSC "IMPLANT N" hudelem text lines (sync_items_hud), freeing ~4 per-client slots.
-- CreateModel-not-GetModel: toplayer models have no node until the first server write (the
-- turbocharger-badge lesson, see AccGunBadgeRow's ACCESSOR CHOICE note above).
--
-- GEOMETRY (virtual 1280x720): the upper-left band y45..406 is clear - HEALTH/shards/EXO/MB moved
-- into the BOTTOM Aetherium PlayerInfo panel (y~595-710), only the Round counter sits top-left
-- (~y45). Cards start at y220; the 4-bar stack ends y406, ~33px above the co-op party panels
-- (y439+). The pause-menu panel (AetheriumStartMenu) mirrors these exact coords to OVERLAP these
-- bars while paused. TUNE IN-GAME like every chip before it.
local ACC_IMPLANT_CARD_W   = 184   -- v4 bars at -20% (user 2026-07-12: "reduce size 20%"); 184/34 = 5.41 ~ 962x176 (5.466:1)
local ACC_IMPLANT_CARD_H   = 34    -- was 42; scaled 0.8
local ACC_IMPLANT_LEFT     = 32    -- left edge (GSC x16 -> LUI x32, same column as the old lines)
local ACC_IMPLANT_TOP      = 220   -- first card's top edge
local ACC_IMPLANT_GAP      = 6     -- vertical gap between cards (stride 34+6 = 40)
local ACC_IMPLANT_EMB_FRAC = 0.92  -- emblem glyph = 92% of bar height (v4 README)
local ACC_IMPLANT_EMB_CX   = 0.901 -- emblem x-center at 90.1% of bar width (v4 README)
-- STATE = PURE IMAGE SWAP (V2 pack, 2026-07-12). Every card ships two PNGs: lit (occupied) and
-- _dim (unoccupied - 35% desat / 60% bright / 50% ALPHA BAKED INTO THE ART per the pack README).
-- Do NOT layer a code setAlpha on the dim state: baked 50% x code 50% = 25%, near-invisible.
-- The 4th HOLDING card (i_acc_implant_holding[_dim]) shows the carried-but-not-benched item with
-- the same emblem-window geometry as the slots.

-- Item num (1..13, _acc_boss_items build_item_pool / ACC_IMPLANT_INFO in AetheriumStartMenu.lua)
-- -> emblem image. KEEP IN SYNC with both on any item add/renumber (num must stay <= 15, 4-bit).
local ACC_IMPLANT_EMBLEMS = {
    [1]  = "i_acc_emblem_sentry_drone",   -- Sentry Drone REPLACED Gas Tank 2026-07-22 (nibble full at 15, num 1 reused)
    [2]  = "i_acc_emblem_loot_stash",
    [3]  = "i_acc_emblem_repair_kit",
    [4]  = "i_acc_emblem_rocket_shield",
    [5]  = "i_acc_emblem_phase_serum",
    [6]  = "i_acc_emblem_boots",
    [7]  = "i_acc_emblem_lucky_horseshoe",
    [8]  = "i_acc_emblem_turbocharger",
    [9]  = "i_acc_emblem_plasma_generator",  -- was nuclear_energy; split into Plasma (9) + Warhead (13) 2026-07-14
    [10] = "i_acc_emblem_battery",
    [11] = "i_acc_emblem_berzerker",
    [12] = "i_acc_emblem_high_caliber",   -- real art 2026-07-15 (zip file emblem_13_high_caliber_round - zip numbering differs, map by NAME)
    [13] = "i_acc_emblem_warhead_bomber", -- real art 2026-07-15 (zip file emblem_12_warhead_bomber - zip numbering differs, map by NAME)
    [14] = "i_acc_emblem_hive_node",      -- real art 2026-07-16 (emblem_14_healing_hive.png, bicubic 256->96 to match the 96x96 emblem convention)
    [15] = "i_acc_emblem_dark_magic",     -- Dark Magic (item 15, 2026-07-17): PLACEHOLDER art (copy of hive_node) until the user's emblem drops in; swap the PNG only, no code change
}

CoD.AccImplantRow = InheritFrom(LUI.UIElement)

function CoD.AccImplantRow.new(HudRef, InstanceRef)
    local self = LUI.UIElement.new()
    self:setClass(CoD.AccImplantRow)
    self.id = "AccImplantRow"
    self:setLeftRight(true, true, 0, 0)
    self:setTopBottom(true, true, 0, 0)

    -- Register every emblem material ONCE; Refresh just swaps pre-registered handles
    -- (the countryside PerkImage setImage idiom, docs/19). Iterate the table by pairs so
    -- EVERY defined emblem gets a handle - a hardcoded upper bound silently drops any item
    -- added past it (bug 2026-07-15: the loop was `1, 11` so High Caliber (12) + Warhead (13)
    -- had nil handles and never rendered in-game, yet the pause panel - which pairs()-iterates
    -- ACC_IMPLANT_INFO - showed them, producing "shows when paused, not in the HUD").
    local handles = {}
    for num, img in pairs(ACC_IMPLANT_EMBLEMS) do
        handles[num] = RegisterImage(img)
    end

    -- Emblem quad inside a card, from the pack README's ratios (188/256 of the card height,
    -- centered on the hex window at 888/1024 of the width).
    local embS = ACC_IMPLANT_CARD_H * ACC_IMPLANT_EMB_FRAC
    local embL = ACC_IMPLANT_LEFT + ACC_IMPLANT_CARD_W * ACC_IMPLANT_EMB_CX - embS / 2
    local embT = (ACC_IMPLANT_CARD_H - embS) / 2

    -- Per-card image handles: lit = occupied, dim = unoccupied (baked-alpha art, see above).
    local cardImgs = {}
    for s = 1, 3 do
        cardImgs[s] = {
            lit = RegisterImage("i_acc_implant_slot" .. s),
            dim = RegisterImage("i_acc_implant_slot" .. s .. "_dim"),
        }
    end
    local holdImgs = {
        lit = RegisterImage("i_acc_implant_holding"),
        dim = RegisterImage("i_acc_implant_holding_dim"),
    }

    local cards = {}
    local overlays = {}
    for s = 1, 3 do
        local top = ACC_IMPLANT_TOP + (s - 1) * (ACC_IMPLANT_CARD_H + ACC_IMPLANT_GAP)

        local card = LUI.UIImage.new()
        card:setLeftRight(true, false, ACC_IMPLANT_LEFT, ACC_IMPLANT_LEFT + ACC_IMPLANT_CARD_W)
        card:setTopBottom(true, false, top, top + ACC_IMPLANT_CARD_H)
        card:setImage(cardImgs[s].dim)   -- starts empty
        self:addElement(card)
        cards[s] = card

        local emb = LUI.UIImage.new()
        emb:setLeftRight(true, false, embL, embL + embS)
        emb:setTopBottom(true, false, top + embT, top + embT + embS)
        emb:hide()
        self:addElement(emb)
        overlays[s] = emb
    end

    -- HOLDING card (4th row): the carried-but-not-benched item - "go enable it at a bench".
    -- Mirrors the old amber CARRY line's condition (the server only packs a carry nibble when
    -- the item isn't already implanted). Empty hands = the dim holding card.
    local carryTop = ACC_IMPLANT_TOP + 3 * (ACC_IMPLANT_CARD_H + ACC_IMPLANT_GAP)
    local holdCard = LUI.UIImage.new()
    holdCard:setLeftRight(true, false, ACC_IMPLANT_LEFT, ACC_IMPLANT_LEFT + ACC_IMPLANT_CARD_W)
    holdCard:setTopBottom(true, false, carryTop, carryTop + ACC_IMPLANT_CARD_H)
    holdCard:setImage(holdImgs.dim)
    self:addElement(holdCard)

    local carry = LUI.UIImage.new()
    carry:setLeftRight(true, false, embL, embL + embS)
    carry:setTopBottom(true, false, carryTop + embT, carryTop + embT + embS)
    carry:hide()
    self:addElement(carry)

    -- Nibble decode by floor-division (no bit ops in HKS Lua 5.1; 16 bits is exact in the
    -- 32-bit float mantissa) - same math as AetheriumStartMenu's AccRefreshImplantPanel.
    local function Refresh(raw)
        local v = tonumber(raw) or 0
        for s = 1, 3 do
            local h = handles[math.floor(v / (16 ^ (s - 1))) % 16]
            if h then
                overlays[s]:setImage(h)
                overlays[s]:show()
                cards[s]:setImage(cardImgs[s].lit)   -- occupied = lit card
            else
                overlays[s]:hide()
                cards[s]:setImage(cardImgs[s].dim)   -- empty = dim card (alpha baked in the art)
            end
        end
        local ch = handles[math.floor(v / 4096) % 16]
        if ch then
            carry:setImage(ch)
            carry:show()
            holdCard:setImage(holdImgs.lit)
        else
            carry:hide()
            holdCard:setImage(holdImgs.dim)
        end
    end

    local implantsModel = Engine.CreateModel(Engine.GetModelForController(InstanceRef), "acc_implants")
    self:subscribeToModel(implantsModel, function(model)
        Refresh(Engine.GetModelValue(model))
    end)
    Refresh(Engine.GetModelValue(implantsModel))   -- initial paint (rejoin/HUD rebuild mid-run)

    -- HIDE WHILE THE PAUSE MENU IS OPEN (user 2026-07-12: the transparent pause menu showed the
    -- implants twice - these cards AND the pause panel's copies). Same BIT_UI_ACTIVE hide the
    -- Aetherium kit uses on all its panels (AetheriumHud.lua); the pause panel is the implant
    -- surface while any fullscreen UI is up.
    self:subscribeToModel(Engine.GetModel(Engine.GetModelForController(InstanceRef),
        "UIVisibilityBit." .. Enum.UIVisibilityBit.BIT_UI_ACTIVE), function(model)
        local v = Engine.GetModelValue(model)
        self:setAlpha((v and v ~= 0) and 0 or 1)
    end)

    return self
end

-- TOUCHPOINT 5 - Cyber "HOSTILES" threat BAR (upper-right). CoD.AccRoundRing. A layered
-- cyberpunk depleting meter: FULL at round start, drains as the round's zombies are killed.
-- Built ENTIRELY from CoD.TextWithBg.Bg rectangles (the only render-safe primitive here - no
-- custom material/shader, docs/29 §14): outer cyan halo, navy track, teal->magenta drain fill,
-- segment notches, a bright "drain front" sliver that rides the fill edge, a top accent line,
-- four corner targeting brackets, and a small "HOSTILES" caption (the % readout was REMOVED per
-- user 2026-06-17). Driven by ONE clientuimodel int (_acc_lui.gsc round_ring_watch):
-- "accRoundRing" = fill percent 0..100; frac = pct/100, teal (full) -> magenta (empty) via
-- acc_ring_color. docs/42.
CoD.AccRoundRing = InheritFrom(LUI.UIElement)

-- Bar geometry (virtual px). Upper-right; tune freely.
local ACC_BAR_W     = 240   -- bar width
local ACC_BAR_H     = 22    -- bar height
local ACC_BAR_RIGHT = 10    -- gap from the right edge (user 2026-06-17: moved right 30, 40->10)
local ACC_BAR_TOPC  = -300  -- vertical offset from screen CENTER (negative = up; user 2026-06-17:
                            -- up 100, -200->-300). Briefly -230 during the Aetherium adoption to
                            -- clear the kit's top-right round digits; those are DISABLED again
                            -- (round counter back to our top-left elem, user 2026-07-03), so the
                            -- bar's original corner spot is restored.
local ACC_BAR_HOTW  = 5     -- width of the bright "drain front" sliver
local ACC_BAR_SEGS  = 8     -- number of segment divisions (draws SEGS-1 notches)
local ACC_BAR_BR_TH = 2     -- corner-bracket arm thickness
local ACC_BAR_BR_LN = 11    -- corner-bracket arm length

function CoD.AccRoundRing.new(HudRef, InstanceRef)
    local self = LUI.UIElement.new()
    self:setClass(CoD.AccRoundRing)
    self.id = "AccRoundRing"
    -- POSITIONED box (proven anchors): right-anchored horizontally (the AccPerkCard idiom) +
    -- vertical offset from CENTER (the AccDmgNum idiom, negative = up). Children fill it.
    self:setLeftRight(false, true, -(ACC_BAR_RIGHT + ACC_BAR_W), -ACC_BAR_RIGHT)
    self:setTopBottom(false, false, ACC_BAR_TOPC, ACC_BAR_TOPC + ACC_BAR_H)

    -- Solid-rectangle helper: an empty CoD.TextWithBg whose .Bg is the visible fill (the proven
    -- render-safe primitive). Caller sets anchors; returns the widget (use .Bg to recolor/move).
    local function Rect(r, g, b, a)
        local e = CoD.TextWithBg.new(HudRef, InstanceRef)
        e.Text:setText("")
        e.Bg:setRGB(r, g, b)
        e.Bg:setAlpha(a)
        return e
    end

    -- (0) Outer cyan halo - a slightly oversized dim rect behind the track = soft glow frame.
    local Halo = Rect(0.12, 0.55, 0.85, 0.16)
    Halo:setLeftRight(true, true, -4, 4)
    Halo:setTopBottom(true, true, -4, 4)
    self:addElement(Halo)

    -- (1) Navy track (empty bar), stretched to fill self.
    local Track = Rect(0, 0.035, 0.085, 0.9)
    Track:setLeftRight(true, true, 0, 0)
    Track:setTopBottom(true, true, 0, 0)
    self:addElement(Track)

    -- (2) Teal->magenta drain fill: resize its inner .Bg to the RIGHT frac of the bar (proven
    -- setLeftRight(true,false,x,x+W) idiom) so the fill shrinks and the empty part grows from left.
    local Fill = Rect(ACC_RING_FULL[1], ACC_RING_FULL[2], ACC_RING_FULL[3], 0.95)
    Fill:setLeftRight(true, true, 0, 0)
    Fill:setTopBottom(true, true, 0, 0)
    self:addElement(Fill)
    self.Fill = Fill

    -- (3) Segment notches - thin dark dividers over the fill = battery / tech-gauge readout.
    for k = 1, ACC_BAR_SEGS - 1 do
        local x = ACC_BAR_W * k / ACC_BAR_SEGS
        local seg = Rect(0, 0.02, 0.05, 0.6)
        seg:setLeftRight(true, false, x - 1, x + 1)
        seg:setTopBottom(true, true, 0, 0)
        self:addElement(seg)
    end

    -- (4) Bright "drain front" sliver - rides the fill's moving left edge (positioned in the
    -- callback). Starts hidden (alpha 0) until the first push places it.
    local Hot = Rect(0.85, 1.0, 1.0, 0)
    Hot:setLeftRight(true, true, 0, 0)
    Hot:setTopBottom(true, true, 0, 0)
    self:addElement(Hot)
    self.Hot = Hot

    -- (5) Top accent line (the perk-card cyan strip idiom).
    local Accent = Rect(0.2, 0.75, 1.0, 0.85)
    Accent:setLeftRight(true, true, 0, 0)
    Accent:setTopBottom(true, false, 0, 2)
    self:addElement(Accent)

    -- (6) Four corner "targeting" brackets (8 thin arms) = cyber-HUD frame.
    local function Bracket(lA, rA, lO, rO, tA, bA, tO, bO)
        local e = Rect(0.3, 0.85, 1.0, 0.9)
        e:setLeftRight(lA, rA, lO, rO)
        e:setTopBottom(tA, bA, tO, bO)
        self:addElement(e)
    end
    local TH, LN = ACC_BAR_BR_TH, ACC_BAR_BR_LN
    Bracket(true,  false,  0,  LN, true,  false,  0,  TH)   -- top-left (horizontal arm)
    Bracket(true,  false,  0,  TH, true,  false,  0,  LN)   -- top-left (vertical arm)
    Bracket(false, true,  -LN,  0, true,  false,  0,  TH)   -- top-right (horizontal)
    Bracket(false, true,  -TH,  0, true,  false,  0,  LN)   -- top-right (vertical)
    Bracket(true,  false,  0,  LN, false, true,  -TH,  0)   -- bottom-left (horizontal)
    Bracket(true,  false,  0,  TH, false, true,  -LN,  0)   -- bottom-left (vertical)
    Bracket(false, true,  -LN,  0, false, true,  -TH,  0)   -- bottom-right (horizontal)
    Bracket(false, true,  -TH,  0, false, true,  -LN,  0)   -- bottom-right (vertical)

    -- Driven by one clientuimodel int: accRoundRing = fill PERCENT 0..100 (0 = round cleared).
    -- SMOOTH SLIDE (user 2026-06-17): the fill + drain-front sliver SLIDE to the new value via the
    -- proven LUI tween (completeAnimation -> beginAnimation, the same call CoD.AccDmgNum uses),
    -- which interpolates the setLeftRight offsets AND setRGB from the current state. The FIRST
    -- update is instant so the (true,false,..) anchor baseline is set before any tween. 250ms ~=
    -- the server push cadence (round_ring_watch waits 0.25s) so steps chain into a continuous drain.
    local ringStarted = false
    self:subscribeToModel(Engine.GetModel(Engine.GetModelForController(InstanceRef), "accRoundRing"), function(m)
        local pct = Engine.GetModelValue(m) or 100
        if pct > 100 then pct = 100 elseif pct < 0 then pct = 0 end
        local frac = pct / 100
        local leftOff = ACC_BAR_W - frac * ACC_BAR_W
        if ringStarted then
            self.Fill.Bg:completeAnimation()
            self.Fill.Bg:beginAnimation("keyframe", 250, false, false, CoD.TweenType.Linear)
            self.Hot.Bg:completeAnimation()
            self.Hot.Bg:beginAnimation("keyframe", 250, false, false, CoD.TweenType.Linear)
        else
            ringStarted = true
        end
        self.Fill.Bg:setLeftRight(true, false, leftOff, ACC_BAR_W)     -- right frac (drains L->R)
        self.Fill.Bg:setRGB(acc_ring_color(1 - frac))                 -- teal (full) -> magenta (empty)
        -- bright drain front rides the fill's left edge; hidden once the round is cleared.
        self.Hot.Bg:setLeftRight(true, false, leftOff - ACC_BAR_HOTW * 0.5, leftOff + ACC_BAR_HOTW * 0.5)
        self.Hot.Bg:setAlpha(frac > 0.02 and 0.95 or 0)
    end)

    return self
end

-- TOUCHPOINT 6 - Data Shards icon (user 2026-06-25). CoD.AccShardIcon. ONE static image anchored TOP-LEFT,
-- replacing the "DATA SHARDS" text label of the server data-shards hudelem (the shard COUNT stays in that
-- hudelem, repositioned just to the RIGHT of this icon). Same setImage(RegisterImage(...)) plain-image path as
-- the perk bar (a usermap CANNOT build a 2D HUD *material* for the legacy hudelem - "No techsetdef for material
-- type 2d" - but the IMAGE links fine). Always visible (no clientfield). Strict subset of CoD.AccPapTierIcon.
-- TUNE LEFT/TOP/SIZE in-game to line up with the count hudelem (server hudelem sits at x16 y50 in 640x480).
CoD.AccShardIcon = InheritFrom(LUI.UIElement)

function CoD.AccShardIcon.new(HudRef, InstanceRef)
    local self = LUI.UIElement.new()
    self:setClass(CoD.AccShardIcon)
    self.id = "AccShardIcon"
    self:setLeftRight(true, true, 0, 0)
    self:setTopBottom(true, true, 0, 0)

    -- LUI canvas is ~1280x720; the server hudelem is 640x480 -> LUI x ~= hudelem*2, LUI y ~= hudelem*1.5
    -- (confirmed in-game: LUI 14,46 landed on the health bar = hudelem ~7,31).
    -- MOVED 2026-07-03 (user: "place shards, mb, and exo under the players player HUD"): the icon now
    -- leads the own-stats row along the BOTTOM edge of the Aetherium PlayerInfo plate (LUI 16..360 x
    -- 595..710). The count/EXO/MB hudelems follow at hudelem x27/x62, BOTTOM_LEFT -16
    -- (_acc_health_bars::ensure_own_stats). TUNE these three + those anchors together in-game.
    local SIZE = 26    -- LUI px (renders square on a 16:9 screen); ~= the 1.05-scale count text height
    local LEFT = 24    -- LUI x  (plate left padding)
    local TOP  = 682   -- LUI y  (bottom strip of the PlayerInfo plate; plate bottom edge = 710)
    local img = LUI.UIImage.new()
    img:setLeftRight(true, false, LEFT, LEFT + SIZE)
    img:setTopBottom(true, false, TOP, TOP + SIZE)
    img:setImage(RegisterImage("i_acc_data_shard"))
    self:addElement(img)

    return self
end

-- TOUCHPOINT 7 - Custom COMBAT HUD (user 2026-06-26): the bottom-right ammo/weapon/equipment block,
-- drawn by US in this safe additive overlay (Track A) instead of the stock ZM ammo widget. The data is
-- read CLIENT-SIDE from the engine's own weapon UIModels - the SAME models the stock zmammo widgets read
-- (zm_building zmammo_*_abbey.lua) - which live in a SEPARATE namespace from our (full) clientuimodel
-- clientfield pool, so this costs ZERO new clientfields. The matching stock block is hidden server-side
-- (_acc_lui.gsc::suppress_stock_weapon_hud -> SetClientUIVisibilityFlag "weapon_hud_visible" 0) so only
-- ours shows. Bindings lifted VERBATIM from the stock widgets (model names are stock-engine, not ours):
--   mag      = globalModel CurrentWeapon.ammoInClip          (zmammo_clipinfo_abbey.lua:24)
--   reserve  = globalModel CurrentWeapon.ammoStock           (zmammo_total_abbey.lua:91)
--   name     = globalModel CurrentWeapon.weaponName          (zmammo_textattachmentinfo_abbey.lua:79)
--   lethal   = globalModel CurrentPrimaryOffhand.primaryOffhand (icon name -> RegisterImage)
--              + per-ctrl currentPrimaryOffhand.primaryOffhandCount   (zmammo_equipcontainer_abbey.lua:181,57)
--   tactical = globalModel CurrentSecondaryOffhand.secondaryOffhand + currentSecondaryOffhand.secondaryOffhandCount
-- NO custom font (stock UI font), NO custom material (plain UIText/UIImage + the CoD.TextWithBg.Bg rect
-- kit), recolored to ACC_PAL teal. subscribeToGlobalModel is proven in a shipped ADDITIVE overlay menu
-- (alien_isolation alien_objective_ui.lua) - same menu class as ours - so it is safe here. docs/49.

-- (Mag colour is computed per-instance inside AccAmmoBlock now - it's RESERVE-driven, not a raw clip count,
--  so a small-clip gun like the MORS doesn't read its full 1/1 clip as "low". See refreshMagColor below.)
CoD.AccAmmoBlock = InheritFrom(LUI.UIElement)

function CoD.AccAmmoBlock.new(HudRef, InstanceRef)
    local self = LUI.UIElement.new()
    self:setClass(CoD.AccAmmoBlock)
    self.id = "AccAmmoBlock"

    -- Bottom-right positioned box (far-edge fixed-box idiom: false,true + negative offsets, same as
    -- AccPapTierIcon). TUNE these 4 in-game to sit it where the stock ammo was. (NOTE: the existing
    -- PaP-tier icon / Overclock vN text are also bottom-right - they may overlap this block until we
    -- reposition them in a follow-up; they still render.)
    local RIGHT  = 40
    local BOTTOM = 46
    local W      = 252
    local H      = 96    -- name header + PaP/OC chips + ammo (user 2026-06-26: tightened from 132->116->96 to kill empty space)
    self:setLeftRight(false, true, -(RIGHT + W), -RIGHT)
    self:setTopBottom(false, true, -(BOTTOM + H), -BOTTOM)

    -- Background plate, accent strip, AND the corner targeting brackets ALL REMOVED (user 2026-06-27: "remove the
    -- whole background rectangle" + "remove those brackets"). The gun name + ammo now float over the scene with no
    -- frame at all. (The Rect/Bracket helpers were deleted too - nothing else in this block used them.)

    -- Weapon NAME (top-RIGHT of the header row, right-aligned, dim cyan). Left of it the header holds
    -- the PaP/OC status chips (AccPapTierIcon / AccOcTierText, repositioned to land here), so the name
    -- box starts well right (112) to avoid colliding with them.
    local NameTxt = LUI.UIText.new()
    NameTxt:setLeftRight(true, true, 12, -4)   -- right pad ->4 (user 2026-06-27: gun name hugs the card's right border; -4 still clears the 2px corner bracket)
    NameTxt:setTopBottom(true, false, 5, 40)
    NameTxt:setAlignment(Enum.LUIAlignment.LUI_ALIGNMENT_RIGHT)
    NameTxt:setScale(0.58)   -- gun-name header (user 2026-06-27: 0.78 still too big - "1.5x not 2x"; dropped ~25%)
    NameTxt:setRGB(0.78, 0.92, 1.0)
    NameTxt:setText("")
    self:addElement(NameTxt)

    -- MAG (hero number, lower-LEFT of the plate, right-aligned, teal->amber->danger by count). Scale
    -- dropped 1.5->1.1 (it was swallowing the reserve + spilling below the plate, user 2026-06-26).
    local MagTxt = LUI.UIText.new()
    MagTxt:setLeftRight(false, true, -162, -62)   -- pulled further right (user 2026-06-27: still deadspace; "56" right edge -62, just left of the reserve)
    MagTxt:setTopBottom(false, true, -46, -4)
    MagTxt:setAlignment(Enum.LUIAlignment.LUI_ALIGNMENT_RIGHT)
    MagTxt:setScale(1.1)
    MagTxt:setRGB(ACC_PAL.teal[1], ACC_PAL.teal[2], ACC_PAL.teal[3])
    MagTxt:setText("")
    self:addElement(MagTxt)

    -- RESERVE "/ N" (to the RIGHT of the mag, smaller, baseline slightly raised, dim). Pulled further right
    -- (user 2026-06-27: still deadspace at -72). Box LEFT at -60: a 3-digit reserve ("/ 999", the realistic max
    -- in this map ~900) ends ~flush at the border; a hypothetical 4-digit reserve (no such gun) would clip its
    -- last digit. Don't pull -60 further right unless you've confirmed no gun shows a 4-digit reserve.
    local ReserveTxt = LUI.UIText.new()
    ReserveTxt:setLeftRight(false, true, -60, -2)
    ReserveTxt:setTopBottom(false, true, -34, -10)
    ReserveTxt:setAlignment(Enum.LUIAlignment.LUI_ALIGNMENT_LEFT)
    ReserveTxt:setScale(0.7)
    ReserveTxt:setRGB(0.66, 0.85, 0.9)
    ReserveTxt:setText("")
    self:addElement(ReserveTxt)

    -- Mag-number colour by RESERVE, not raw clip count (user 2026-06-26): TEAL normally, AMBER in the last
    -- ~20% of your reserve (running low on TOTAL ammo), DANGER (magenta) when fully out. So a small-clip gun
    -- like the MORS reads its full 1/1 clip as TEAL, not "always low". maxReserve = the highest reserve seen
    -- for the current weapon (re-baselined on weapon switch) so "20%" is relative to THAT weapon's stockpile.
    local curClip    = 0
    local curReserve = 0
    local maxReserve = 0

    local function refreshMagColor()
        local c = ACC_PAL.teal
        if curClip <= 0 and curReserve <= 0 then
            c = ACC_PAL.danger
        elseif maxReserve > 0 and curReserve <= maxReserve * 0.2 then
            c = ACC_PAL.amber
        end
        MagTxt:setRGB(c[1], c[2], c[3])
    end

    -- Ammo text: a no-magazine weapon (melee like the Action Figure) reports 0 clip + 0 reserve - show "-/-"
    -- instead of a meaningless "0 / 0" (user 2026-06-27). A normal gun only hits this when TRULY out of all ammo,
    -- where "-/-" still reads correctly. Otherwise show the live clip + reserve.
    local function refreshAmmoText()
        if curClip <= 0 and curReserve <= 0 then
            MagTxt:setText("-")
            ReserveTxt:setText("/ -")
        else
            MagTxt:setText(tostring(curClip))
            ReserveTxt:setText("/ " .. tostring(curReserve))
        end
    end

    self:subscribeToGlobalModel(InstanceRef, "CurrentWeapon", "ammoInClip", function(model)
        local v = Engine.GetModelValue(model)
        if v then
            curClip = tonumber(v) or 0
            refreshAmmoText()
            refreshMagColor()
        end
    end)
    self:subscribeToGlobalModel(InstanceRef, "CurrentWeapon", "ammoStock", function(model)
        local v = Engine.GetModelValue(model)
        if v then
            curReserve = tonumber(v) or 0
            if curReserve > maxReserve then maxReserve = curReserve end
            refreshAmmoText()
            refreshMagColor()
        end
    end)
    -- Weapon switch: re-baseline maxReserve so the 20% threshold tracks the NEW weapon, not the old one.
    self:subscribeToModel(Engine.GetModel(Engine.GetModelForController(InstanceRef), "currentWeapon.weapon"), function(model)
        maxReserve = 0
        refreshAmmoText()
        refreshMagColor()
    end)
    self:subscribeToGlobalModel(InstanceRef, "CurrentWeapon", "weaponName", function(model)
        local v = Engine.GetModelValue(model)
        if v then NameTxt:setText(Engine.Localize(v)) end
    end)

    return self
end

-- Equipment: lethal + tactical icon (engine-supplied image name) + count, just ABOVE the ammo block.
-- Each slot hides when its count is 0 or it has no icon. Icons come free from the offhand models -
-- no authored art.
CoD.AccEquip = InheritFrom(LUI.UIElement)

function CoD.AccEquip.new(HudRef, InstanceRef)
    local self = LUI.UIElement.new()
    self:setClass(CoD.AccEquip)
    self.id = "AccEquip"

    -- Row sitting RIGHT ABOVE the ammo device card (the card's top edge is at BOTTOM 46 + H 96 = 142 from the
    -- screen bottom; this row's BOTTOM=144 leaves it flush against that top, no dead space - user 2026-06-27:
    -- was 168 = a 26-unit gap of padding for no reason). TUNE in-game.
    local RIGHT  = 44
    local BOTTOM = 144
    local W      = 170
    local H      = 38
    self:setLeftRight(false, true, -(RIGHT + W), -RIGHT)
    self:setTopBottom(false, true, -(BOTTOM + H), -BOTTOM)

    -- One slot = count (UIText, left) + icon (UIImage, right) anchored from the row's RIGHT edge, `rightOff` in.
    local function Slot(rightOff)
        local SIZE = 32
        local icon = LUI.UIImage.new()
        icon:setLeftRight(false, true, -(rightOff + SIZE), -rightOff)
        icon:setTopBottom(false, true, -SIZE, 0)
        icon:setRGB(ACC_PAL.teal[1], ACC_PAL.teal[2], ACC_PAL.teal[3])
        icon:hide()
        self:addElement(icon)

        local cnt = LUI.UIText.new()
        cnt:setLeftRight(false, true, -(rightOff + SIZE + 24), -(rightOff + SIZE + 2))
        cnt:setTopBottom(false, true, -30, -2)
        cnt:setAlignment(Enum.LUIAlignment.LUI_ALIGNMENT_RIGHT)
        cnt:setScale(0.78)
        cnt:setRGB(0.78, 0.92, 1.0)
        cnt:setText("")
        self:addElement(cnt)

        return { icon = icon, cnt = cnt, count = 0, img = "" }
    end

    local lethal   = Slot(6)    -- rightmost
    local tactical = Slot(86)   -- left of lethal

    local function refresh(slot)
        if slot.count > 0 and slot.img ~= "" then
            slot.icon:show()
            slot.cnt:setText(tostring(slot.count))
        else
            slot.icon:hide()
            slot.cnt:setText("")
        end
    end

    -- Lethal: icon name (CurrentPrimaryOffhand.primaryOffhand) + count (per-ctrl primaryOffhandCount).
    self:subscribeToGlobalModel(InstanceRef, "CurrentPrimaryOffhand", "primaryOffhand", function(model)
        local v = Engine.GetModelValue(model)
        if v and v ~= "" then
            lethal.img = v
            lethal.icon:setImage(RegisterImage(v))
        else
            lethal.img = ""
        end
        refresh(lethal)
    end)
    self:subscribeToModel(Engine.GetModel(Engine.GetModelForController(InstanceRef), "currentPrimaryOffhand.primaryOffhandCount"), function(model)
        lethal.count = Engine.GetModelValue(model) or 0
        refresh(lethal)
    end)

    -- Tactical: secondaryOffhand icon + secondaryOffhandCount.
    self:subscribeToGlobalModel(InstanceRef, "CurrentSecondaryOffhand", "secondaryOffhand", function(model)
        local v = Engine.GetModelValue(model)
        if v and v ~= "" then
            tactical.img = v
            tactical.icon:setImage(RegisterImage(v))
        else
            tactical.img = ""
        end
        refresh(tactical)
    end)
    self:subscribeToModel(Engine.GetModel(Engine.GetModelForController(InstanceRef), "currentSecondaryOffhand.secondaryOffhandCount"), function(model)
        tactical.count = Engine.GetModelValue(model) or 0
        refresh(tactical)
    end)

    return self
end

-- TOUCHPOINT 4f - LEVEL + XP bar (docs/45, DEV-ONLY leveling). CoD.AccLevel. Bottom-left widget
-- built on the USER-SUPPLIED art frame i_acc_level_frame (512x128 PNG, installed 2026-07-20 via
-- source_data/acc_perk_shaders.gdt + the zone image line): a hex emblem with an empty dark-glass
-- center (we render the big level NUMBER there - the "LEVEL" caption is baked into the art) and a
-- bar track whose interior is FULLY TRANSPARENT - our teal fill rect draws BEHIND the PNG and shows
-- through that window, so the fill never covers the frame's neon border. Zone geometry below was
-- MEASURED from the PNG's alpha channel (tools-session scan 2026-07-20), not assumed. Driven by the
-- per-player CONTROLLER UI-model "accLevel" = "<lvl>|<frac>|<gain>|<seq>" pushed by _acc_leveling::
-- push_level_hud - ZERO clientfield bits (all three CF pools are full), per-player, coop-replicated.
-- Read with Engine.CreateModel (the controller-model node has no data until the first server write -
-- the turbocharger-badge lesson; CreateModel is idempotent, so it catches the first push). Whole
-- thing is inert in ship (the server never pushes accLevel unless dev is on -> widget stays hidden).
local ACC_LVL_LEFT   = 24    -- x gap from the LEFT edge (TUNE IN-GAME)
local ACC_LVL_W      = 160   -- display width; H = W/4 keeps the PNG's exact 4:1 aspect
local ACC_LVL_H      = 40    -- display height (512x128 / 3.2); master is ~1.6x real display px,
                             -- the same pre-downscale band as the shipped implant cards (552x102
                             -- for a 184x34 box) - safe with noMipMaps 1
local ACC_LVL_BOTTOM = 9     -- bottom-left corner, raised 5 (user 2026-07-22; was 4). AetheriumPlayerInfo
                             -- rides -30 (AetheriumHud.lua), freeing the corner strip - chip y671..711
local ACC_LVL_TEAL   = { 0.20, 0.95, 0.85 }          -- ACC_PAL.teal - XP fill + level number
local ACC_LVL_AMBER  = { 1.0,  0.88, 0.25 }          -- ACC_PAL.amber - the "+N XP" gain floater
-- MEASURED master-px geometry (do not eyeball-edit; re-run the alpha scan if the art changes):
local ACC_LVL_IMG_W  = 512
local ACC_LVL_IMG_H  = 128
local ACC_LVL_WIN_X0 = 140   -- transparent bar window: x 140..489 inclusive (alpha==0, hard edges)
local ACC_LVL_WIN_X1 = 490   -- exclusive right edge
local ACC_LVL_WIN_Y0 = 52    -- window y 52..75 inclusive
local ACC_LVL_WIN_Y1 = 76    -- exclusive bottom edge
local ACC_LVL_EMB_CX = 70.5  -- emblem dark-glass center (level-number anchor)
local ACC_LVL_EMB_CY = 63.5
local ACC_LVL_SX     = ACC_LVL_W / ACC_LVL_IMG_W     -- master px -> display units (0.3125)
local ACC_LVL_SY     = ACC_LVL_H / ACC_LVL_IMG_H
local ACC_LVL_FILL_W = (ACC_LVL_WIN_X1 - ACC_LVL_WIN_X0) * ACC_LVL_SX   -- full-bar fill width

CoD.AccLevel = InheritFrom(LUI.UIElement)

function CoD.AccLevel.new(HudRef, InstanceRef)
    local self = LUI.UIElement.new()
    self:setClass(CoD.AccLevel)
    self.id = "AccLevel"

    -- Positioned box, bottom-left: left-anchored X, bottom-anchored Y with negative offsets
    -- (the proven far-edge fixed-box idiom).
    self:setLeftRight(true, false, ACC_LVL_LEFT, ACC_LVL_LEFT + ACC_LVL_W)
    self:setTopBottom(false, true, -(ACC_LVL_BOTTOM + ACC_LVL_H), -ACC_LVL_BOTTOM)

    -- Solid-rectangle helper (the AccRoundRing primitive: an empty CoD.TextWithBg whose .Bg is the fill).
    local function Rect(r, g, b, a)
        local e = CoD.TextWithBg.new(HudRef, InstanceRef)
        e.Text:setText("")
        e.Bg:setRGB(r, g, b)
        e.Bg:setAlpha(a)
        return e
    end

    -- (0) XP FILL - added FIRST so the frame PNG (next) draws OVER it: the fill is only visible
    -- through the window's transparent interior, so its edges never cover the neon border. The
    -- fill ELEMENT spans the full window; render() resizes its .Bg to the earned fraction.
    local Fill = Rect(ACC_LVL_TEAL[1], ACC_LVL_TEAL[2], ACC_LVL_TEAL[3], 0.95)
    Fill:setLeftRight(true, false, ACC_LVL_WIN_X0 * ACC_LVL_SX, ACC_LVL_WIN_X1 * ACC_LVL_SX)
    Fill:setTopBottom(true, false, ACC_LVL_WIN_Y0 * ACC_LVL_SY, ACC_LVL_WIN_Y1 * ACC_LVL_SY)
    self:addElement(Fill)
    self.Fill = Fill

    -- (1) the art frame, stretched over the whole chip box (same 4:1 aspect, so no distortion).
    local Frame = LUI.UIImage.new()
    Frame:setLeftRight(true, true, 0, 0)
    Frame:setTopBottom(true, true, 0, 0)
    Frame:setImage(RegisterImage("i_acc_level_frame"))
    self:addElement(Frame)

    -- (2) the LEVEL NUMBER, centered in the emblem's dark-glass circle (the art bakes the "LEVEL"
    -- caption; we render digits only). Box centered on the measured glass center. TUNE IN-GAME.
    local Num = LUI.UIText.new()
    -- box center = measured glass center MINUS 3 (screenshot tune, user 2026-07-21: "level number
    -- moved to left 3 points" - the digit sat right of the glass center)
    Num:setLeftRight(true, false, ACC_LVL_EMB_CX * ACC_LVL_SX - 23, ACC_LVL_EMB_CX * ACC_LVL_SX + 17)
    Num:setTopBottom(true, false, ACC_LVL_EMB_CY * ACC_LVL_SY - 10, ACC_LVL_EMB_CY * ACC_LVL_SY + 10)
    Num:setAlignment(Enum.LUIAlignment.LUI_ALIGNMENT_CENTER)
    Num:setScale(0.95)
    Num:setRGB(ACC_LVL_TEAL[1], ACC_LVL_TEAL[2], ACC_LVL_TEAL[3])
    Num:setText("0")
    self:addElement(Num)
    self.Num = Num

    -- (3) "+N XP" gain floater - just RIGHT of the chip (children may extend past the parent box;
    -- LUI does not clip). Painted + faded by render() whenever a push carries a NEW gain (seq
    -- changed); the fade is the proven completeAnimation->beginAnimation alpha tween (AccDmgNum/
    -- AccRoundRing idiom). Starts invisible. Vertically centered on the bar window.
    local Gain = LUI.UIText.new()
    -- +5 right (screenshot tune, user 2026-07-21: "xp number moved over by 5 points" - clears the
    -- frame's right-edge neon glow)
    Gain:setLeftRight(true, false, ACC_LVL_W + 13, ACC_LVL_W + 123)
    Gain:setTopBottom(true, false, 11, 29)
    Gain:setAlignment(Enum.LUIAlignment.LUI_ALIGNMENT_LEFT)
    Gain:setScale(0.75)
    Gain:setRGB(ACC_LVL_AMBER[1], ACC_LVL_AMBER[2], ACC_LVL_AMBER[3])
    Gain:setText("")
    Gain:setAlpha(0)
    self:addElement(Gain)
    self.Gain = Gain

    -- Paint from the "<lvl>|<frac>|<gain>|<seq>" payload (string.find/sub/tonumber - the
    -- ZMCursorHintNew form; gain/seq are optional so an older 2-field payload still parses).
    -- SHOW ONLY once the server has pushed a real payload, which ALWAYS contains '|'. The server
    -- pushes accLevel only in dev (push_level_hud rides the dev-gated hooks), so in SHIP this widget
    -- stays hidden no matter what an unwritten controller-model node defaults to (nil / "" / the
    -- number 0) - NO stray "LV 0" chip in normal play. (It is built for every player; LUI cannot
    -- read level.acc_dev, so the '|' gate is what enforces "hidden unless truly active".)
    local lastGainSeq = nil
    local function render(s)
        if type(s) ~= "string" then s = nil end
        local sep = s and string.find(s, "|", 1, true)
        if not sep then
            self:hide()
            return
        end
        self:show()
        local lvl  = tonumber(string.sub(s, 1, sep - 1)) or 0
        local rest = string.sub(s, sep + 1)
        local frac, gain, seq = 0, 0, nil
        local sep2 = string.find(rest, "|", 1, true)
        if sep2 then
            frac = tonumber(string.sub(rest, 1, sep2 - 1)) or 0
            local tail = string.sub(rest, sep2 + 1)
            local sep3 = string.find(tail, "|", 1, true)
            if sep3 then
                gain = tonumber(string.sub(tail, 1, sep3 - 1)) or 0
                seq  = string.sub(tail, sep3 + 1)
            else
                gain = tonumber(tail) or 0
            end
        else
            frac = tonumber(rest) or 0
        end
        if frac < 0 then frac = 0 elseif frac > 1 then frac = 1 end
        self.Num:setText("" .. lvl)
        -- resize the fill's .Bg within the fill element (which spans the transparent window);
        -- grows from the window's left edge.
        self.Fill.Bg:setLeftRight(true, false, 0, ACC_LVL_FILL_W * frac)

        -- "+N XP" floater: seq is the server's per-PUSH id (bumped on EVERY push so each payload is
        -- a unique string - that uniqueness is what makes re-pushes deliver into a freshly reopened
        -- menu at all; unchanged model values never re-fire this subscription). Flash only when the
        -- push actually carries a gain: grant pushes have gain>0, spawn/re-open pushes have gain 0.
        -- Fade = the proven completeAnimation -> beginAnimation alpha tween.
        if gain > 0 and seq ~= nil and seq ~= lastGainSeq then
            lastGainSeq = seq
            self.Gain:setText("+" .. gain .. " XP")
            self.Gain:completeAnimation()
            self.Gain:setAlpha(1)
            self.Gain:beginAnimation("keyframe", 1400, false, false, CoD.TweenType.Linear)
            self.Gain:setAlpha(0)
        elseif seq ~= nil then
            lastGainSeq = seq   -- track without flashing (e.g. the spawn push after a respawn)
        end
    end

    local model = Engine.CreateModel(Engine.GetModelForController(InstanceRef), "accLevel")
    self:subscribeToModel(model, function(m)
        render(Engine.GetModelValue(m))
    end)
    render(Engine.GetModelValue(model))   -- initial paint (rejoin / HUD rebuild mid-run)

    return self
end

-- TOUCHPOINT 8 - BOSS HEALTH BARS (2026-07-24, user: "an actual bar would make sense
-- rather than text"). CoD.AccBossBars. Up to 5 stacked boss rows in the upper-right
-- THREAT column, directly under the HOSTILES bar (same width + right gap = one aligned
-- device): boss NAME above a real depleting bar, built from the AccRoundRing rect kit
-- (halo / navy track / BOSS-IDENTITY-color fill (ACC_BB_BOSS_COLORS, name-keyed - the
-- ONLY boss indicator since 2026-07-25 - the 3D plate is removed) / dim same-hue
-- damage-GHOST trail / white drain-front sliver / 33%-66% phase notches - docs/15
-- boss-health-bar phase markers). Replaces the
-- 3D nameplate's ASCII "[||||------]" (the plate keeps the floating NAME for in-world
-- identity - _acc_boss_nameplate.csc). NO numeric HP anywhere (docs/31: progress bars
-- carry no drawn number).
--
-- Driven by FIVE per-player controller UI-models (the accLevel channel - ZERO
-- clientfield bits, co-op replicated, spectate-safe), pushed by _acc_boss_nameplate.gsc
-- bb_* at 4 Hz change-guarded:
--     "accBoss1".."accBoss5" = "<NAME>|<pct, 5% steps>|<state>[|r<n>]"
--     state 1 = alive (paint/update) | 0 = killed (white flash + fade-out) | 2 = hide
-- pct is quantized and only the per-life REPUSH window appends the |r<n> uniquifier
-- (2026-07-25 BGCACHE find: every unique payload registers a finite client
-- configstring - steady pushes rely on the server's change guard instead; the parser
-- below handles both the 3- and 4-field forms). Rows are
-- fixed positions (server backfills freed slots) - a brief gap after a death is fine,
-- overflow bosses (6+) simply wait for a free row (the 3D plate is gone).
local ACC_BB_SLOTS   = 5                                -- rows (4 -> 5 user 2026-07-24, Scientist added); LOCKSTEP with ACC_BB_SLOTS + the accBoss* precaches in _acc_boss_nameplate.gsc
local ACC_BB_W       = ACC_BAR_W                        -- same width as the HOSTILES bar above
local ACC_BB_BAR_H   = 12                               -- bar height (slimmer than HOSTILES' 22 = clear hierarchy)
local ACC_BB_NAME_H  = 16                               -- name row height above each bar
local ACC_BB_TOP0    = ACC_BAR_TOPC + ACC_BAR_H + 14    -- first row sits just under the HOSTILES bar (center-offset units)
local ACC_BB_STRIDE  = ACC_BB_NAME_H + ACC_BB_BAR_H + 12  -- row pitch (40): name + bar + inter-row gap
local ACC_BB_HOTW    = 3                                -- drain-front sliver width
local ACC_BB_FADE_MS = 900                              -- kill flash/fade length; server holds the slot 1200ms (ACC_BB_FREE_DELAY_MS) so this finishes first

-- Per-BOSS identity colors (user 2026-07-24 "each boss to have its own color: Phantom
-- Yellow, brutus red, avogodro cyan, rogue protector blue, Panzer gray, scientist
-- white"): keyed by the payload NAME, applied to the row's LED + name + halo + ghost +
-- fill when a boss arms it. TRUE colors, exactly as asked - the 2026-07-25
-- tint-calibrated palette (gold-orange/sea-teal/green/taupe/peach) was REVERTED the
-- same day when the 3D plate was removed: the warm hostile-name tint that forced it
-- only ever applied to the engine's draw-name renderer, and LUI rects render exact RGB.
-- The bars are the ONLY boss indicator, so nothing constrains this table anymore.
local ACC_BB_BOSS_COLORS = {
    ["PHANTOM"]         = { 1.0,  0.85, 0.2  },   -- yellow
    ["TRENCH WARDEN"]   = { 0.95, 0.2,  0.18 },   -- red - Brutus
    ["AVOGADRO"]        = { 0.2,  0.9,  1.0  },   -- cyan
    ["ROGUE PROTECTOR"] = { 0.25, 0.45, 1.0  },   -- blue (renders TRUE here - only the removed 3D channel couldn't)
    ["PANZER"]          = { 0.62, 0.65, 0.7  },   -- gray
    ["THE SCIENTIST"]   = { 0.95, 0.97, 1.0  },   -- white
}
local ACC_BB_DEFAULT_COLOR = { 0.90, 0.20, 0.55 }   -- unknown/future boss: house danger magenta

CoD.AccBossBars = InheritFrom(LUI.UIElement)

function CoD.AccBossBars.new(HudRef, InstanceRef)
    local self = LUI.UIElement.new()
    self:setClass(CoD.AccBossBars)
    self.id = "AccBossBars"
    self:setLeftRight(true, true, 0, 0)
    self:setTopBottom(true, true, 0, 0)

    -- Solid-rectangle helper (the AccRoundRing primitive: empty CoD.TextWithBg, .Bg = fill).
    local function Rect(r, g, b, a)
        local e = CoD.TextWithBg.new(HudRef, InstanceRef)
        e.Text:setText("")
        e.Bg:setRGB(r, g, b)
        e.Bg:setAlpha(a)
        return e
    end

    -- Build the 4 rows up-front, hidden; renderSlot() shows/paints them as payloads land
    -- (the AccGunBadgeRow prebuilt-children idiom - zero churn as bosses come and go).
    self.slots = {}
    for i = 1, ACC_BB_SLOTS do
        local top = ACC_BB_TOP0 + (i - 1) * ACC_BB_STRIDE
        local slot = {}
        -- Built in the neutral default hue; the ARMING pass (renderSlot fresh path)
        -- retints LED/name/halo/ghost/fill to the occupying BOSS's identity color.
        local C = ACC_BB_DEFAULT_COLOR
        slot.color = C

        local group = LUI.UIElement.new()
        group:setLeftRight(false, true, -(ACC_BAR_RIGHT + ACC_BB_W), -ACC_BAR_RIGHT)
        group:setTopBottom(false, false, top, top + ACC_BB_NAME_H + ACC_BB_BAR_H)
        self:addElement(group)
        slot.group = group

        -- Name row: the boss-color "threat LED" square + the boss name in the kit's
        -- display font (orbitron - the Aetherium name/header font, shipped-active in
        -- AetheriumPlayerInfo.lua:165), BOTH retinted to the boss identity color so
        -- each row owns its boss identity color (the ONLY indicator - no 3D plate).
        local Led = Rect(C[1], C[2], C[3], 0.9)
        Led:setLeftRight(true, false, 0, 6)
        Led:setTopBottom(true, false, 5, 11)
        group:addElement(Led)
        slot.Led = Led

        local NameTxt = LUI.UIText.new()
        NameTxt:setLeftRight(true, true, 12, 0)
        NameTxt:setTopBottom(true, false, 0, ACC_BB_NAME_H)
        NameTxt:setTTF("fonts/orbitron.ttf")
        NameTxt:setAlignment(Enum.LUIAlignment.LUI_ALIGNMENT_LEFT)
        NameTxt:setScale(0.62)   -- 0.5 -> 0.62 (user 2026-07-25 "boss name needs to be slightly bigger")
        NameTxt:setRGB(C[1], C[2], C[3])
        NameTxt:setAlpha(0.95)
        NameTxt:setText("")
        group:addElement(NameTxt)
        slot.NameTxt = NameTxt

        -- Bar stack (all rects, bar area = y NAME_H .. NAME_H+BAR_H inside the group):
        -- (0) soft halo frame in the boss color (the AccRoundRing glow idiom)
        local Halo = Rect(C[1], C[2], C[3], 0.13)
        Halo:setLeftRight(true, true, -3, 3)
        Halo:setTopBottom(true, false, ACC_BB_NAME_H - 3, ACC_BB_NAME_H + ACC_BB_BAR_H + 3)
        group:addElement(Halo)
        slot.Halo = Halo

        -- (1) navy glass track (the empty bar)
        local Track = Rect(ACC_PAL.glass[1], ACC_PAL.glass[2], ACC_PAL.glass[3], 0.9)
        Track:setLeftRight(true, true, 0, 0)
        Track:setTopBottom(true, false, ACC_BB_NAME_H, ACC_BB_NAME_H + ACC_BB_BAR_H)
        group:addElement(Track)

        -- (2) DIM damage-GHOST: same box + hue as the fill but at low alpha, on a slower
        -- tween window - the trail reads as a dimmer band of the boss's own color on any
        -- hue (a fixed pale color washed out against the yellow/white fills). Under
        -- sustained 4Hz damage the per-push completeAnimation() snap keeps it ~one push
        -- behind the fill (a classic trailing damage chip); once fire stops, the final
        -- 600ms tween plays out fully and the chip drains into the track.
        local Ghost = Rect(C[1], C[2], C[3], 0.4)
        Ghost:setLeftRight(true, false, 0, ACC_BB_W)
        Ghost:setTopBottom(true, false, ACC_BB_NAME_H, ACC_BB_NAME_H + ACC_BB_BAR_H)
        group:addElement(Ghost)
        slot.Ghost = Ghost

        -- (3) the health fill - the BOSS identity color, anchored LEFT (drains right->left,
        -- the mirror of the HOSTILES bar so the two never read as the same gauge).
        local Fill = Rect(C[1], C[2], C[3], 0.95)
        Fill:setLeftRight(true, false, 0, ACC_BB_W)
        Fill:setTopBottom(true, false, ACC_BB_NAME_H, ACC_BB_NAME_H + ACC_BB_BAR_H)
        group:addElement(Fill)
        slot.Fill = Fill

        -- (4) phase notches at 33% / 66% (docs/15 boss-health-bar phase markers)
        local NotchA = Rect(0, 0.02, 0.05, 0.65)
        NotchA:setLeftRight(true, false, ACC_BB_W / 3 - 1, ACC_BB_W / 3 + 1)
        NotchA:setTopBottom(true, false, ACC_BB_NAME_H, ACC_BB_NAME_H + ACC_BB_BAR_H)
        group:addElement(NotchA)
        local NotchB = Rect(0, 0.02, 0.05, 0.65)
        NotchB:setLeftRight(true, false, ACC_BB_W * 2 / 3 - 1, ACC_BB_W * 2 / 3 + 1)
        NotchB:setTopBottom(true, false, ACC_BB_NAME_H, ACC_BB_NAME_H + ACC_BB_BAR_H)
        group:addElement(NotchB)

        -- (5) bright drain-front sliver riding the fill's right edge. WHITE so it reads on
        -- every row hue. The ELEMENT spans the FULL bar (review fix 2026-07-24: Bg offsets
        -- are element-relative, so a 3px-wide element put the sliver 237px off-target) -
        -- the AccRoundRing Hot idiom: full-span element, then renderSlot places the Bg at
        -- edge +/- HOTW/2 in bar coords.
        local Hot = Rect(1, 1, 1, 0)
        Hot:setLeftRight(true, true, 0, 0)
        Hot:setTopBottom(true, false, ACC_BB_NAME_H, ACC_BB_NAME_H + ACC_BB_BAR_H)
        group:addElement(Hot)
        slot.Hot = Hot

        -- Everything that fades on a kill (fill flashes separately), with its resting
        -- alpha so a backfilled boss restores the row. Hot rests at 0 (edge logic owns it).
        slot.fade = {
            { e = Led.Bg,    a = 0.9  },
            { e = NameTxt,   a = 0.95 },
            { e = Halo.Bg,   a = 0.13 },
            { e = Track.Bg,  a = 0.9  },
            { e = Ghost.Bg,  a = 0.4  },
            { e = NotchA.Bg, a = 0.65 },
            { e = NotchB.Bg, a = 0.65 },
            { e = Hot.Bg,    a = 0    },
        }

        group:hide()   -- hidden until the server paints a live payload
        slot.mode = nil
        self.slots[i] = slot
    end

    -- Paint one row from its "<NAME>|<pct>|<state>|<seq>" payload (the accLevel
    -- string.find/sub/tonumber parse; seq is only there to make each push unique).
    local function renderSlot(i, s)
        local slot = self.slots[i]
        if type(s) ~= "string" then slot.group:hide() slot.mode = nil return end
        local sep = string.find(s, "|", 1, true)
        if not sep then slot.group:hide() slot.mode = nil return end
        local name = string.sub(s, 1, sep - 1)
        local rest = string.sub(s, sep + 1)
        local pct, state = 0, 2
        local sep2 = string.find(rest, "|", 1, true)
        if sep2 then
            pct = tonumber(string.sub(rest, 1, sep2 - 1)) or 0
            local tail = string.sub(rest, sep2 + 1)
            local sep3 = string.find(tail, "|", 1, true)
            if sep3 then
                state = tonumber(string.sub(tail, 1, sep3 - 1)) or 2
            else
                state = tonumber(tail) or 2
            end
        else
            pct = tonumber(rest) or 0
        end

        if state == 2 then   -- clear: hide immediately (Paradise wipe / empty-slot repush)
            slot.group:hide()
            slot.mode = nil
            return
        end

        if state == 0 then   -- killed: full-width white kill-pop, whole row fades in place
            if slot.mode ~= "alive" then return end
            slot.mode = "dying"
            slot.Fill.Bg:completeAnimation()
            slot.Fill.Bg:setLeftRight(true, false, 0, ACC_BB_W)   -- pop the FULL bar, not the last sliver
            slot.Fill.Bg:setRGB(1, 1, 1)
            slot.Fill.Bg:setAlpha(1)
            slot.Fill.Bg:beginAnimation("keyframe", ACC_BB_FADE_MS, false, false, CoD.TweenType.Linear)
            slot.Fill.Bg:setAlpha(0)
            for k = 1, #slot.fade do
                local f = slot.fade[k]
                f.e:completeAnimation()
                f.e:beginAnimation("keyframe", ACC_BB_FADE_MS, false, false, CoD.TweenType.Linear)
                f.e:setAlpha(0)
            end
            return
        end

        -- state 1: live row
        if pct < 0 then pct = 0 elseif pct > 100 then pct = 100 end
        local frac = pct / 100
        local fresh = (slot.mode ~= "alive")
        if fresh then
            -- (re)arm: retint the row to THIS boss's identity color (matches its 3D
            -- title), restore every part's resting alpha, paint instant (the
            -- ringStarted rule - first update sets the baseline).
            local C = ACC_BB_BOSS_COLORS[name] or ACC_BB_DEFAULT_COLOR
            slot.color = C
            slot.group:show()
            slot.Led.Bg:setRGB(C[1], C[2], C[3])
            slot.NameTxt:setRGB(C[1], C[2], C[3])
            slot.Halo.Bg:setRGB(C[1], C[2], C[3])
            slot.Ghost.Bg:completeAnimation()
            slot.Ghost.Bg:setRGB(C[1], C[2], C[3])
            slot.Fill.Bg:completeAnimation()
            slot.Fill.Bg:setRGB(C[1], C[2], C[3])
            slot.Fill.Bg:setAlpha(0.95)
            for k = 1, #slot.fade do
                local f = slot.fade[k]
                f.e:completeAnimation()
                f.e:setAlpha(f.a)
            end
            slot.mode = "alive"
        end
        if slot.shownName ~= name then
            slot.NameTxt:setText(name)
            slot.shownName = name
        end
        local edge = ACC_BB_W * frac
        if not fresh then
            slot.Fill.Bg:completeAnimation()
            slot.Fill.Bg:beginAnimation("keyframe", 250, false, false, CoD.TweenType.Linear)   -- matches the 0.25s server cadence (AccRoundRing grammar)
            slot.Ghost.Bg:completeAnimation()
            slot.Ghost.Bg:beginAnimation("keyframe", 600, false, false, CoD.TweenType.Linear)  -- slower than the fill: rides ~one push behind under fire, drains fully after the last hit (review-tuned 900->600, the snap-forward per push is smaller)
            slot.Hot.Bg:completeAnimation()
            slot.Hot.Bg:beginAnimation("keyframe", 250, false, false, CoD.TweenType.Linear)
        end
        slot.Fill.Bg:setLeftRight(true, false, 0, edge)
        slot.Ghost.Bg:setLeftRight(true, false, 0, edge)
        slot.Hot.Bg:setLeftRight(true, false, edge - ACC_BB_HOTW * 0.5, edge + ACC_BB_HOTW * 0.5)
        slot.Hot.Bg:setAlpha((frac > 0.02 and frac < 0.995) and 0.9 or 0)
    end

    -- One controller-model subscription per row. Engine.CreateModel, NEVER GetModel -
    -- these nodes don't exist until the first server write (the turbocharger-badge
    -- lesson); CreateModel is idempotent. Initial read covers a mid-run HUD rebuild.
    for i = 1, ACC_BB_SLOTS do
        local model = Engine.CreateModel(Engine.GetModelForController(InstanceRef), "accBoss" .. i)
        self:subscribeToModel(model, function(m)
            renderSlot(i, Engine.GetModelValue(m))
        end)
        renderSlot(i, Engine.GetModelValue(model))
    end

    return self
end

function LUI.createMenu.acc_hud(Instance)
    local Hud = CoD.Menu.NewForUIEditor("acc_hud")

    Hud.soundSet = "HUD"
    Hud:setOwner(Instance)
    Hud:setLeftRight(true, true, 0, 0)
    Hud:setTopBottom(true, true, 0, 0)

    -- RETIRED (user 2026-07-03: "remove our old UI - the new UI is better when buying"):
    -- CoD.AccPerkCard, the right-side perk/PaP info card. The Aetherium cursor-hint prompt
    -- (PromptPerks, now MEGA-AWARE with bottle-cost display) owns the buy UX. NOTE: this card
    -- also carried the Overclock (codes 44-63) + Exo Suit (108-127) walk-up REPORT cards -
    -- those displays are gone with it (the kiosk/station hint strings still show the basics).
    -- Class kept above; to restore:
    --     local Card = CoD.AccPerkCard.new(Hud, Instance)
    --     Hud:addElement(Card); Hud.accCard = Card
    -- (and re-add the OnHudClose accCard:close() call at the bottom of createMenu).

    local DmgNum = CoD.AccDmgNum.new(Hud, Instance)
    Hud:addElement(DmgNum)
    Hud.accDmgNum = DmgNum

    -- RETIRED (Aetherium HUD adoption, 2026-07-03): CoD.AccPerkBar - the Aetherium perk row
    -- (AetheriumPerksContainer, REWIRED to the same accOwnedMask/accMegaMask masks + the same
    -- Ronan base/mega icons) draws the perks now. Class kept above; to restore, re-add:
    --     local PerkBar = CoD.AccPerkBar.new(Hud, Instance)
    --     Hud:addElement(PerkBar)
    --     Hud.accPerkBar = PerkBar

    -- RETIRED (Aetherium HUD adoption, 2026-07-03): CoD.AccPowerupBar - Aetherium's
    -- PowerupsContainer draws power-ups from the STOCK powerup clientfields (the server-side
    -- suppressor that used to null them is retired in _acc_lui.gsc behind the same flag).
    -- Class kept above; to restore, re-add the 3 lines (PowerupBar mirror of the PerkBar recipe)
    -- AND re-enable the _acc_lui.gsc powerup threads (level.acc_aetherium_hud = false does both).

    -- PaP-tier icon + Overclock "vN" chip are registered LATER (after the ammo block) so they draw ON
    -- TOP of the translucent device plate as header status chips - see below.

    -- Round-progress bar: a teal cyber health-bar (upper-right) that drains as the round's
    -- zombies are killed, with a "pct%" readout. Driven by accRoundRing (fill percent 0..100).
    local RoundRing = CoD.AccRoundRing.new(Hud, Instance)
    Hud:addElement(RoundRing)
    Hud.accRoundRing = RoundRing

    -- BOSS HEALTH BARS (2026-07-24): up to 5 NAME-over-bar rows stacked under the
    -- HOSTILES bar, each tinted to its boss identity color, driven by the accBoss1..5
    -- controller UI-models
    -- (_acc_boss_nameplate.gsc bb_*). Replaces the 3D plate's ASCII text bar (the
    -- plate keeps the floating boss NAME for in-world identity).
    local BossBars = CoD.AccBossBars.new(Hud, Instance)
    Hud:addElement(BossBars)
    Hud.accBossBars = BossBars

    -- RETIRED again (user 2026-07-03, currencies-in-panel pass): CoD.AccShardIcon + the
    -- _acc_health_bars own-stats hudelem row are superseded - shards/MB/EXO now render INSIDE
    -- the Aetherium PlayerInfo panel (toplayer clientfields acc_shards/acc_mb/acc_exo ->
    -- AetheriumPlayerInfo.lua currency row). To restore the standalone icon:
    --     local ShardIcon = CoD.AccShardIcon.new(Hud, Instance)
    --     Hud:addElement(ShardIcon); Hud.accShardIcon = ShardIcon

    -- RETIRED (Aetherium HUD adoption, 2026-07-03): CoD.AccAmmoBlock + CoD.AccEquip - the
    -- Aetherium Loadout widget (bottom-right plate, LR 885-1312 / TB 512-720) draws weapon name/
    -- ammo/equipment from the same engine client models. Classes kept above; to restore, re-add:
    --     local AmmoBlock = CoD.AccAmmoBlock.new(Hud, Instance)
    --     Hud:addElement(AmmoBlock); Hud.accAmmoBlock = AmmoBlock
    --     local Equip = CoD.AccEquip.new(Hud, Instance)
    --     Hud:addElement(Equip); Hud.accEquip = Equip
    -- AND flip level.acc_aetherium_hud = false in _acc_lui.gsc (re-arms suppress_stock_weapon_hud).

    -- GUN BADGE ROW (2026-07-08, user: "unify the gun badges"): ONE right-anchored chip row under
    -- the ammo readout - PaP shield / "OC vN" / "MULE" / "TURBO" - packing leftward as badges
    -- appear. Registered after the (Aetherium) plate region so it draws on top. RETIRED the three
    -- one-off chips it replaces (AccPapTierIcon / AccOcTierText / AccMuleTag - restore recipe):
    --     local PapTier = CoD.AccPapTierIcon.new(Hud, Instance)
    --     Hud:addElement(PapTier); Hud.accPapTierIcon = PapTier
    --     local OcTier = CoD.AccOcTierText.new(Hud, Instance)
    --     Hud:addElement(OcTier); Hud.accOcTierText = OcTier
    --     local MuleTag = CoD.AccMuleTag.new(Hud, Instance)
    --     Hud:addElement(MuleTag); Hud.accMuleTag = MuleTag
    -- (AccMuleTag's acc_mule field became bit 0 of acc_badges - restoring it also needs the
    -- 1-bit acc_mule toplayer field back in _zm_aetherium_hud.gsc/.csc, in lockstep.)
    local BadgeRow = CoD.AccGunBadgeRow.new(Hud, Instance)
    Hud:addElement(BadgeRow)
    Hud.accGunBadgeRow = BadgeRow

    -- IMPLANT SLOT CARDS (2026-07-12): three left-side slot-card PNGs + emblem overlays riding
    -- the acc_implants nibble wire; replaced the GSC "IMPLANT N" hudelem text lines (docs/09).
    local ImplantRow = CoD.AccImplantRow.new(Hud, Instance)
    Hud:addElement(ImplantRow)
    Hud.accImplantRow = ImplantRow

    -- LEVEL + XP bar (docs/45, DEV-ONLY leveling): bottom-left "LV N" + XP progress bar, driven by
    -- the accLevel controller UI-model. Inert in ship (server never pushes accLevel unless dev on).
    local LevelChip = CoD.AccLevel.new(Hud, Instance)
    Hud:addElement(LevelChip)
    Hud.accLevel = LevelChip

    -- (AccPerkCard retired 2026-07-03 -> no accCard:close() override needed; re-add with it.)

    return Hud
end
-- ACC_GSCONLY_SIZE_PROBE_BLOCK_BEGIN xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx ACC_GSCONLY_SIZE_PROBE_BLOCK_END
