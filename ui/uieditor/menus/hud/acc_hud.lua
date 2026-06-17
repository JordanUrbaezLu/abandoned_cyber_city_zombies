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

-- The Armory (Mule Kick Mega) makes all buys 10% cheaper. 10% off, floored to a clean
-- multiple of 10 - MUST match the GSC (armory_discounted / _acc_pap_levels keeper).
local function acc_discount(n)
    return math.floor(n * 0.9 / 10) * 10
end

-- Pack-a-Punch tier text (MUST mirror _acc_pap_levels.gsc tier_benefit / tier_repack_cost +
-- ACC_PAP_FIRST_PACK_COST). 3-tier revamp 2026-06-16: the transform ("_up" form) is DEFERRED
-- to tier 2; tier 1 is camo + damage only.
local function pap_tier_benefit(tier)
    if tier == 1 then return "+50% damage + new camo" end
    if tier == 2 then return "+100% damage + upgraded form" end
    if tier == 3 then return "+150% weapon damage (MAX)" end
    return ""
end
local function pap_tier_cost(tier)
    if tier == 1 then return 5000 end  -- first pack (the machine's own cost; may differ on a sale)
    if tier == 2 then return 7500 end
    if tier == 3 then return 10000 end
    return 0
end

-- Perk card content. Index MUST match _acc_perk_info::perk_card_index.
--   base     = benefits of the BASE perk (shown on the buy card + as the Mega preview's
--              "before"); mega = what the Mega bottle ADDS/UPGRADES (shown when you own
--              base but haven't Mega'd - mode 1). megaFull = the single merged list shown
--              once you OWN the Mega (mode 2): every effective benefit, with Mega values
--              REPLACING the base ones they supersede (no "+50%" AND "+70%" - just "+70%").
local AccPerkCards = {
    [1] = { title = "JUGGER-NOG", price = "4000", megaName = "Ultimate Tank",
            base = { "250 HP - down on the 6th hit", "(no perk: 100 HP / 3rd hit)" },
            mega = { "314 HP - down on the 7th hit", "Immune to boss abilities" },
            megaFull = { "314 HP - down on the 7th hit", "Immune to boss abilities" } },
    [2] = { title = "QUICK REVIVE", price = "2500", megaName = "Savior",
            base = { "Revive teammates in 2.0s", "Regen starts 15% sooner", "Solo: self-revive" },
            mega = { "Revive in 1.0s", "Regen starts 30% sooner", "+15% speed near a downed ally" },
            megaFull = { "Revive teammates in 1.0s", "Regen starts 30% sooner", "Solo: self-revive", "+15% speed near a downed ally" } },
    [3] = { title = "SPEED COLA", price = "3500", megaName = "Sleight of Hand Expert",
            base = { "+50% reload speed", "Faster barrier repair" },
            mega = { "+75% reload speed" },
            megaFull = { "+75% reload speed", "Faster barrier repair" } },
    [4] = { title = "DOUBLE TAP 2.0", price = "5000", megaName = "Gun Slinger",
            base = { "Fires 2 bullets/shot (~2x dmg)", "+33% rate of fire" },
            mega = { "+40% rate of fire" },
            megaFull = { "Fires 2 bullets/shot (~2x dmg)", "+40% rate of fire" } },
    [5] = { title = "STAMIN-UP", price = "2000", megaName = "The Flash",
            base = { "Longer sprint (~12s)", "+7-8% movement speed" },
            mega = { "+15% movement speed" },
            megaFull = { "Longer sprint (~12s)", "+15% movement speed" } },
    [6] = { title = "MULE KICK", price = "2500", megaName = "The Armory",
            base = { "Carry a 3rd primary weapon" },
            mega = { "+35% reserve ammo each round", "All buys 10% cheaper" },
            megaFull = { "Carry a 3rd primary weapon", "+35% reserve ammo each round", "All buys 10% cheaper" } },
    [7] = { title = "DEADSHOT", price = "3500", megaName = "American Sniper",
            base = { "+1.4 headshot dmg bonus", "ADS snaps to head (not bosses)" },
            mega = { "+1.6 headshot dmg bonus", "-50% weapon recoil" },
            megaFull = { "+1.6 headshot dmg bonus", "-50% weapon recoil", "ADS snaps to head (not bosses)" } },
    [8] = { title = "WIDOW'S WINE", price = "4000", megaName = "Spiderman",
            base = { "Web grenades trap zombies 16s (slow 12s)", "Self-defense + melee webbing", "Restock 2 web nades / round" },
            mega = { "Hold up to 6 web grenades", "Restock 4 / round (vs 2)" },
            megaFull = { "Web grenades trap zombies 16s (slow 12s)", "Self-defense + melee webbing", "Hold up to 6 web grenades", "Restock 4 web nades / round" } },
    [9] = { title = "PHD FLOPPER", price = "2500", megaName = "PhD Slider",
            base = { "Immune to fall + your own explosive damage", "Slide to set off an explosion (clears zombies)", "Explode when you go down" },
            mega = { "Bigger explosion, shorter slide cooldown" },
            megaFull = { "Immune to fall + your own explosive damage", "Slide: BIG explosion (shorter cooldown)", "Explode when you go down" } },
    [10] = { title = "PACK-A-PUNCH", price = "",
            base = { "Pack a gun, then re-pack to climb tiers:", "T1: +50% damage + camo (5000)",
                     "T2: +100% damage + UPGRADE (7500)", "T3: +150% damage MAX (10000)" } },
}

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
    Accent.Bg:setRGB(0.2, 0.75, 1.0)
    Accent.Bg:setAlpha(0.9)
    self:addElement(Accent)

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
    local cardModel = Engine.GetModel(Engine.GetModelForController(InstanceRef), "accPerkCard")

    local function RenderCard(ModelRef)
        local code = Engine.GetModelValue(ModelRef)
        if not code or code == 0 then
            self:hide()
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
        if idx == 10 then
            -- Pack-a-Punch: show ONLY the next tier you'd get (not the whole ladder).
            title = d.title
            titleCol = { 0.72, 0.45, 1.0 }
            bulletCol = { 0.80, 0.66, 1.0 }
            if papTier >= 3 then
                sub = "Tier 3 / 3 - MAX"
                bullets = { "+150% weapon damage (MAX)" } -- short: avoids wrap at scale 0.85
            else
                local nextTier = papTier + 1
                sub = "Tier " .. papTier .. " / 3 - re-pack to raise"
                local costLine
                if pap_tier_cost(nextTier) > 0 then
                    local pc = pap_tier_cost(nextTier)
                    if discounted then
                        costLine = "Cost: " .. acc_discount(pc) .. " Points (-10%)"
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
                    sub = "Cost: " .. acc_discount(p) .. " Points (-10%)"
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

    -- PaP tier: update + re-render the card (only matters while the PaP card is up).
    self:subscribeToModel(Engine.GetModel(Engine.GetModelForController(InstanceRef), "accPapTier"), function(m)
        papTier = Engine.GetModelValue(m) or 0
        RenderCard(cardModel)
    end)

    self:hide()
    return self
end

-- Crosshair damage number. Driven by the "accDmgNum" model (value = dmg*2 + parity;
-- 0 = hide). Centered just above the crosshair so it reads as damage on the zombie
-- you're aiming at. Reliable screen-space LUI (no objective/waypoint override).
CoD.AccDmgNum = InheritFrom(LUI.UIElement)

function CoD.AccDmgNum.new(HudRef, InstanceRef)
    local self = LUI.UIElement.new()
    self:setClass(CoD.AccDmgNum)
    self:setLeftRight(false, false, -160, 160) -- centered, 320 wide
    self:setTopBottom(false, false, -170, -120) -- above the crosshair
    self.id = "AccDmgNum"

    local Num = LUI.UIText.new()
    Num:setLeftRight(true, true, 0, 0)
    Num:setTopBottom(true, true, 0, 0)
    Num:setAlignment(Enum.LUIAlignment.LUI_ALIGNMENT_CENTER)
    Num:setScale(1.9)
    Num:setRGB(1.0, 0.88, 0.25)
    Num:setAlpha(0)
    self:addElement(Num)
    self.Num = Num

    local function OnDmg(ModelRef)
        local v = Engine.GetModelValue(ModelRef) or 0
        if v == 0 then
            -- No recent damage: fade out.
            self.Num:completeAnimation()
            self.Num:beginAnimation("keyframe", 350, false, false, CoD.TweenType.Linear)
            self.Num:setAlpha(0)
            return
        end
        local dmg = math.floor(v / 2)
        if dmg <= 0 then return end
        self.Num:completeAnimation()
        self.Num:setText(tostring(dmg))
        self.Num:setAlpha(1.0)
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
    [8] = "phd",
}
local ACC_PERK_COUNT = 9

CoD.AccPerkBar = InheritFrom(LUI.UIElement)

function CoD.AccPerkBar.new(HudRef, InstanceRef)
    local self = LUI.UIElement.new()
    self:setClass(CoD.AccPerkBar)
    self.id = "AccPerkBar"
    self:setLeftRight(true, true, 0, 0)
    self:setTopBottom(true, true, 0, 0)

    -- Bottom-left row. These 4 numbers position the whole bar - tune in-game.
    local SIZE = 44     -- icon width/height (virtual px)
    local PITCH = 38    -- horizontal spacing between owned icons (tighter = lower)
    local START_X = 96  -- left offset of the first icon (clears the round counter)
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

    -- Pack owned perks left-to-right (perk_card_index order); red=base / teal=Mega.
    local function Render()
        local slot = 0
        for i = 0, ACC_PERK_COUNT - 1 do
            local rec = icons[i]
            if acc_bit_is_set(ownedMask, i) then
                local x = START_X + slot * PITCH
                rec.img:setLeftRight(true, false, x, x + SIZE)
                local wantArt = acc_bit_is_set(megaMask, i) and "mega" or "base"
                if wantArt ~= rec.art then
                    rec.art = wantArt
                    rec.img:setImage(RegisterImage("i_acc_perk_" .. ACC_PERK_ICONS[i] .. "_" .. wantArt))
                end
                rec.img:show()
                slot = slot + 1
            else
                rec.img:hide()
            end
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
    local SIZE = 40       -- icon width/height (virtual px)
    local RIGHT = 67      -- gap from the right edge (final position, user 2026-06-17)
    local BOTTOM = 82     -- gap from the bottom edge (final position, user 2026-06-17)

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

-- TOUCHPOINT 5 - Cyber round-progress BAR (upper-right). CoD.AccRoundRing. A health-bar-style
-- meter: FULL at round start, the teal fill drains (left-to-right) as the round's zombies are
-- killed, with a "pct%" readout centered on it. Built from CoD.TextWithBg.Bg rectangles (the
-- proven-to-render primitive used by the perk card) - no material/shader. Driven by ONE
-- clientuimodel int (_acc_lui.gsc round_ring_watch): "accRoundRing" = fill percent 0..100;
-- frac = pct/100, teal (full) -> magenta (empty) via acc_ring_color. We show % (not raw zombie
-- counts) because wider count fields overflow the full clientuimodel pool. docs/42.
CoD.AccRoundRing = InheritFrom(LUI.UIElement)

-- Bar geometry (virtual px). Upper-right; tune freely.
local ACC_BAR_W     = 240   -- bar width
local ACC_BAR_H     = 22    -- bar height (room for the count text)
local ACC_BAR_RIGHT = 40    -- gap from the right edge
local ACC_BAR_TOPC  = -200  -- vertical offset from screen CENTER (negative = up toward the top)

function CoD.AccRoundRing.new(HudRef, InstanceRef)
    local self = LUI.UIElement.new()
    self:setClass(CoD.AccRoundRing)
    self.id = "AccRoundRing"
    -- POSITIONED box (proven anchors): right-anchored horizontally (the AccPerkCard idiom) +
    -- vertical offset from CENTER (the AccDmgNum idiom, negative = up). Children fill it.
    self:setLeftRight(false, true, -(ACC_BAR_RIGHT + ACC_BAR_W), -ACC_BAR_RIGHT)
    self:setTopBottom(false, false, ACC_BAR_TOPC, ACC_BAR_TOPC + ACC_BAR_H)

    -- Navy track (empty bar) = a TextWithBg STRETCHED to fill self (the proven AccPerkCard
    -- CardBg pattern). Always visible.
    local Track = CoD.TextWithBg.new(HudRef, InstanceRef)
    Track:setLeftRight(true, true, 0, 0)
    Track:setTopBottom(true, true, 0, 0)
    Track.Text:setText("")
    Track.Bg:setRGB(0, 0.035, 0.085)
    Track.Bg:setAlpha(0.9)
    self:addElement(Track)

    -- Teal fill: resize its inner .Bg (a UIImage) to the LEFT frac of the bar (the proven
    -- AccPerkBar setLeftRight(true,false,x,x+W) idiom) so the teal shrinks right-to-left.
    local Fill = CoD.TextWithBg.new(HudRef, InstanceRef)
    Fill:setLeftRight(true, true, 0, 0)
    Fill:setTopBottom(true, true, 0, 0)
    Fill.Text:setText("")
    Fill.Bg:setRGB(ACC_RING_FULL[1], ACC_RING_FULL[2], ACC_RING_FULL[3])
    Fill.Bg:setAlpha(0.95)
    self:addElement(Fill)
    self.Fill = Fill

    -- "left / total" count, centered on the bar (health-bar readout, on top of the fill).
    local Label = LUI.UIText.new()
    Label:setLeftRight(true, true, 0, 0)
    Label:setTopBottom(true, true, 0, 0)
    Label:setAlignment(Enum.LUIAlignment.LUI_ALIGNMENT_CENTER)
    Label:setScale(0.5)
    Label:setRGB(0.92, 0.97, 1.0)
    self:addElement(Label)
    self.Label = Label

    -- Driven by one clientuimodel int: accRoundRing = fill PERCENT 0..100 (the raw zombie
    -- counts would need wider fields than the full clientuimodel pool allows). frac = pct/100;
    -- text = "pct%". (docs/42: the clientfield pool is the constraint behind showing % not counts.)
    self:subscribeToModel(Engine.GetModel(Engine.GetModelForController(InstanceRef), "accRoundRing"), function(m)
        local pct = Engine.GetModelValue(m) or 100
        if pct > 100 then pct = 100 elseif pct < 0 then pct = 0 end
        local frac = pct / 100
        self.Fill.Bg:setLeftRight(true, false, ACC_BAR_W - frac * ACC_BAR_W, ACC_BAR_W)   -- right frac (drains L->R)
        self.Fill.Bg:setRGB(acc_ring_color(1 - frac))                 -- teal (full) -> magenta (empty)
        self.Label:setText(pct .. "%")
    end)

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

    local DmgNum = CoD.AccDmgNum.new(Hud, Instance)
    Hud:addElement(DmgNum)
    Hud.accDmgNum = DmgNum

    -- Mega perk-icon row: one cyberpunk icon per owned perk (red=base / teal=Mega),
    -- packed left-to-right at the bottom. Driven by accOwnedMask + accMegaMask.
    local PerkBar = CoD.AccPerkBar.new(Hud, Instance)
    Hud:addElement(PerkBar)
    Hud.accPerkBar = PerkBar

    -- Power-up active icons: Insta-Kill / Double Points / Fire Sale (Ronan art), top-center,
    -- shown only while each power-up is active. Driven by accPowerupMask.
    local PowerupBar = CoD.AccPowerupBar.new(Hud, Instance)
    Hud:addElement(PowerupBar)
    Hud.accPowerupBar = PowerupBar

    -- Pack-a-Punch tier icon: one roman-numeral cyber shield (I/II/III) over the gadget circle
    -- (bottom-right), shown for the held weapon's current PaP tier. Driven by accPapTier.
    local PapTier = CoD.AccPapTierIcon.new(Hud, Instance)
    Hud:addElement(PapTier)
    Hud.accPapTierIcon = PapTier

    -- Round-progress bar: a teal cyber health-bar (upper-right) that drains as the round's
    -- zombies are killed, with a "pct%" readout. Driven by accRoundRing (fill percent 0..100).
    local RoundRing = CoD.AccRoundRing.new(Hud, Instance)
    Hud:addElement(RoundRing)
    Hud.accRoundRing = RoundRing

    local function OnHudClose(Sender)
        Sender.accCard:close()
    end
    LUI.OverrideFunction_CallOriginalSecond(Hud, "close", OnHudClose)

    return Hud
end
-- ACC_GSCONLY_SIZE_PROBE_BLOCK_BEGIN xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx ACC_GSCONLY_SIZE_PROBE_BLOCK_END
