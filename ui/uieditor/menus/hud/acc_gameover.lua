-- acc_gameover.lua - THE GAME-OVER BACKDROP (docs/40 retry-on-death v3, user
-- 2026-07-25: tower-map style death screen - "YOU DIED" + squad stats + a real
-- decision instead of the old IPrintLnBold splash + auto-dump to the BO3 lobby).
--
-- ARCHITECTURE (v3): this menu is the DISPLAY layer only - YOU DIED, the squad stats
-- table, TIME SURVIVED, the RUN SAVED chip and the auto-exit countdown. The CHOICE
-- itself is a real navigable menu: _acc_leaderboard.gsc::offer_retry_on_death
-- re-enables the ingame menu (stock disables it at end_game), force-opens
-- StartMenu_Main and AetheriumStartMenu.lua's game-over mode (dvar acc_go_active)
-- shows exactly two native up/down buttons - Restart Map / End Game (user 2026-07-25
-- "make it a menu like when you pause a game you can go up and down from controller";
-- the earlier hold-melee/hold-aim gestures are GONE). The pause menu's button column
-- lives at x868-1210, so everything here is shifted LEFT (X_OFF) to compose beside it.
--
-- TRANSPORT: NO controller UI models - that pool is FULL (memory
-- controller-uimodel-pool-full; every accGo* create threw live 2026-07-25):
--   - Squad stats need no transport: stock-replicated PlayerList.<i> models
--     (playerName/playerScore/clientNum) + Engine.GetScoreboardColumnForClient
--     (clientNum, 1/2/3/4 = kills/downs/revives/headshots) - the AetheriumScoreboard
--     data path, present on EVERY machine. Round = gameScore.roundsPlayed model.
--   - acc_go_info "round|H:MM:SS|rec" + acc_go_exit countdown ride dvars polled by
--     ONE UITimer (the proven GSC->LUI channel; host machine only - co-op peers keep
--     the client-side round and the placeholder tile).
--
-- Timer hygiene per memory lui-uitimer-leaks-state-pool: one handle, closed on menu
-- close (OverrideFunction hook, the acc_lb_board pattern). LAYOUT RULE inherited from
-- acc_lb_board.lua: one text scale per column set. Palette mirrors acc_hud.lua
-- ACC_PAL (docs/49) - keep in sync. Whitelist-clean (docs/19).

local COL_GLASS  = { 0,    0.035, 0.085 }
local COL_CYAN   = { 0.2,  0.75,  1.0   }
local COL_TEAL   = { 0.20, 0.95,  0.85  }
local COL_VIOLET = { 0.72, 0.45,  1.0   }
local COL_AMBER  = { 1.0,  0.88,  0.25  }
local COL_DANGER = { 0.90, 0.20,  0.55  }
local COL_TEXT   = { 0.86, 0.90,  0.95  }
local COL_TITLE  = { 0.55, 0.85,  1.0   }
local COL_DEAD   = { 1.0,  0.22,  0.28  }   -- the one off-palette tone: death red

-- everything below is CENTER-anchored then shifted left by X_OFF so the death summary
-- composes beside the pause menu's button column (x868-1210) instead of under it
local X_OFF = -140

-- stats panel geometry (panel-local px). Columns match the tower-map reference:
-- PLAYER | SCORE | KILLS | DOWNS | REVIVES | HEADSHOTS.
local PANEL_W = 720
local PAD     = 26
local X_P0, X_P1 = PAD, 278            -- PLAYER (left-aligned)
local X_S0, X_S1 = 284, 368            -- SCORE
local X_K0, X_K1 = 374, 444            -- KILLS
local X_D0, X_D1 = 450, 520            -- DOWNS
local X_R0, X_R1 = 526, 606            -- REVIVES
local X_H0, X_H1 = 612, PANEL_W - PAD  -- HEADSHOTS
local SC     = 0.75                    -- ONE scale for header + every stat cell
local ROW_H  = 24
local PANEL_Y = 232                    -- panel top (screen px, 1280x720 canvas)

local function trunc(s, n)
	s = tostring(s or "")
	if string.len(s) > n then return string.sub(s, 1, n - 2) .. ".." end
	return s
end

-- split "a|b|c" -> array (fields are delimiter-free by construction in GSC)
local function split(s)
	local out = {}
	for tok in string.gmatch(tostring(s or ""), "([^|]+)") do
		table.insert(out, tok)
	end
	return out
end

-- resilient dvar read: engine builds differ on the exact signature, so try the
-- known forms in order (the shipped AetheriumStartMenu idiom)
local function dvarStr(name)
	local tries = {
		function() return Engine.DvarString(Engine.GetLocalClientNum(), name) end,
		function() return Engine.DvarString(name) end,
		function() return Engine.GetDvarString(name) end,
	}
	for i = 1, #tries do
		local ok, r = pcall(tries[i])
		if ok and r ~= nil then return tostring(r) end
	end
	return ""
end

function LUI.createMenu.acc_gameover(InstanceRef)
	local Hud = CoD.Menu.NewForUIEditor("acc_gameover")
	Hud:setOwner(InstanceRef)
	Hud:setLeftRight(true, true, 0, 0)
	Hud:setTopBottom(true, true, 0, 0)

	local ctrlModel = Engine.GetModelForController(InstanceRef)   -- acc_hud.lua idiom

	-- everything lives under one root so the whole screen fades in as a unit
	local root = LUI.UIElement.new()
	root:setLeftRight(true, true, 0, 0)
	root:setTopBottom(true, true, 0, 0)
	root:setAlpha(0)
	Hud:addElement(root)

	-- ===== primitives (acc_lb_board recipe, screen-anchored + X_OFF shift) ===
	local function box(x0, x1, y0, y1, c, a)
		local e = CoD.TextWithBg.new(Hud, InstanceRef)
		e:setLeftRight(false, false, x0 + X_OFF, x1 + X_OFF)
		e:setTopBottom(true, false, y0, y1)
		e.Text:setText("")
		e.Bg:setRGB(c[1], c[2], c[3])
		e.Bg:setAlpha(a)
		root:addElement(e)
		return e
	end
	local ALIGN = { l = Enum.LUIAlignment.LUI_ALIGNMENT_LEFT,
	                c = Enum.LUIAlignment.LUI_ALIGNMENT_CENTER,
	                r = Enum.LUIAlignment.LUI_ALIGNMENT_RIGHT }
	local function label(x0, x1, y0, h, scale, txt, c, a, align)
		local t = LUI.UIText.new()
		t:setLeftRight(false, false, x0 + X_OFF, x1 + X_OFF)
		t:setTopBottom(true, false, y0, y0 + h)
		t:setAlignment(ALIGN[align or "l"])
		t:setScale(scale)
		t:setText(txt)
		t:setRGB(c[1], c[2], c[3])
		t:setAlpha(a or 1)
		root:addElement(t)
		return t
	end
	local function tween(e, ms)
		e:completeAnimation()
		e:beginAnimation("keyframe", ms, false, false, CoD.TweenType.Linear)
	end

	-- ===== full-screen dim (X_OFF-compensated back to true full width) =======
	box(-640 - X_OFF, 640 - X_OFF, 0, 720, { 0, 0.01, 0.03 }, 0.6)

	-- ===== header ============================================================
	label(-500, 500, 74, 62, 1.0, "YOU DIED", COL_DEAD, 1, "c")
	label(-500, 500, 142, 16, 0.7, "// NEURAL LINK SEVERED - CITY GRID CONNECTION LOST", COL_TITLE, 0.65, "c")
	local survived = label(-500, 500, 172, 26, 0.95, "YOU SURVIVED", COL_TEXT, 0.95, "c")

	-- ===== squad stats panel =================================================
	-- row count = party size from the client-side PlayerList models (the board's own
	-- count idiom); every read pcall'd (playerName can be userdata - memory
	-- lb-playername-localize-not-tostring - display goes through Engine.Localize,
	-- tostring is only used as a non-empty probe).
	local rowCount = 0
	pcall(function()
		for i = 0, 3 do
			local nm = Engine.GetModelValue(Engine.GetModel(ctrlModel, "PlayerList." .. i .. ".playerName"))
			if nm ~= nil and tostring(nm) ~= "" then rowCount = rowCount + 1 end
		end
	end)
	if rowCount < 1 then rowCount = 1 end
	if rowCount > 4 then rowCount = 4 end

	local headerH = 46
	local panelH = headerH + rowCount * ROW_H + 14
	local PX = -PANEL_W / 2   -- panel left edge in center-anchored space
	box(PX, PX + PANEL_W, PANEL_Y, PANEL_Y + panelH, COL_GLASS, 0.84)
	box(PX, PX + PANEL_W, PANEL_Y, PANEL_Y + 3, COL_CYAN, 0.9)
	box(PX, PX + PANEL_W, PANEL_Y + panelH - 3, PANEL_Y + panelH, COL_CYAN, 0.9)

	local hy = PANEL_Y + 12
	label(PX + X_P0, PX + X_P1, hy, 18, SC, "PLAYER",    COL_CYAN, 0.7, "l")
	label(PX + X_S0, PX + X_S1, hy, 18, SC, "SCORE",     COL_CYAN, 0.7, "r")
	label(PX + X_K0, PX + X_K1, hy, 18, SC, "KILLS",     COL_CYAN, 0.7, "r")
	label(PX + X_D0, PX + X_D1, hy, 18, SC, "DOWNS",     COL_CYAN, 0.7, "r")
	label(PX + X_R0, PX + X_R1, hy, 18, SC, "REVIVES",   COL_CYAN, 0.7, "r")
	label(PX + X_H0, PX + X_H1, hy, 18, SC, "HEADSHOTS", COL_CYAN, 0.7, "r")
	box(PX + PAD - 8, PX + PANEL_W - PAD + 8, PANEL_Y + 34, PANEL_Y + 35, COL_CYAN, 0.35)

	local rows = {}
	for i = 1, rowCount do
		local ry = PANEL_Y + headerH + (i - 1) * ROW_H
		if i % 2 == 0 then
			box(PX + 10, PX + PANEL_W - 10, ry - 2, ry + ROW_H - 4, COL_CYAN, 0.05)
		end
		rows[i] = {
			clientNum = nil,
			name = label(PX + X_P0, PX + X_P1, ry, 20, SC, "PLAYER " .. i, COL_TEXT, 0.6, "l"),
			s    = label(PX + X_S0, PX + X_S1, ry, 20, SC, "-", COL_AMBER,  0.9, "r"),
			k    = label(PX + X_K0, PX + X_K1, ry, 20, SC, "-", COL_TEXT,   0.9, "r"),
			d    = label(PX + X_D0, PX + X_D1, ry, 20, SC, "-", COL_DANGER, 0.9, "r"),
			r    = label(PX + X_R0, PX + X_R1, ry, 20, SC, "-", COL_TEAL,   0.9, "r"),
			h    = label(PX + X_H0, PX + X_H1, ry, 20, SC, "-", COL_TEXT,   0.9, "r"),
		}
	end

	-- fill one row's stat cells from the client-side scoreboard columns
	-- (1=kills 2=downs 3=revives 4=headshots - AetheriumScoreboard.lua:391-409)
	local function refreshRowStats(row)
		if row.clientNum == nil or row.clientNum < 0 then return end
		pcall(function()
			row.k:setText(Engine.Localize(Engine.GetScoreboardColumnForClient(row.clientNum, 1)))
			row.d:setText(Engine.Localize(Engine.GetScoreboardColumnForClient(row.clientNum, 2)))
			row.r:setText(Engine.Localize(Engine.GetScoreboardColumnForClient(row.clientNum, 3)))
			row.h:setText(Engine.Localize(Engine.GetScoreboardColumnForClient(row.clientNum, 4)))
		end)
	end

	-- stock-model bindings per row: name / score / clientNum. GetModel (not
	-- CreateModel) is correct here - these are STOCK models that already exist.
	for i = 1, rowCount do
		local row = rows[i]
		local idx = i - 1
		local function bind(sub, fn)
			pcall(function()
				local m = Engine.GetModel(ctrlModel, "PlayerList." .. idx .. "." .. sub)
				if m == nil then return end
				local v = Engine.GetModelValue(m)
				if v ~= nil then pcall(fn, v) end
				Hud:subscribeToModel(m, function(model)
					local nv = Engine.GetModelValue(model)
					if nv ~= nil then pcall(fn, nv) end
				end)
			end)
		end
		bind("playerName", function(v)
			if tostring(v) ~= "" then
				row.name:setText(Engine.Localize(v))
				row.name:setAlpha(0.95)
			end
		end)
		bind("playerScore", function(v)
			row.s:setText(Engine.Localize(v))
		end)
		bind("clientNum", function(v)
			row.clientNum = tonumber(v)
			refreshRowStats(row)
		end)
	end

	-- round: stock gameScore.roundsPlayed (client-side truth on every machine)
	local function setRound(n)
		local rounds = tonumber(n) or 0
		if rounds < 1 then rounds = 1 end
		local word = (rounds == 1 and " ROUND") or " ROUNDS"
		survived:setText("YOU SURVIVED " .. rounds .. word)
	end
	pcall(function()
		local m = Engine.GetModel(ctrlModel, "gameScore.roundsPlayed")
		if m == nil then return end
		local v = Engine.GetModelValue(m)
		if v ~= nil then setRound(v) end
		Hud:subscribeToModel(m, function(model)
			local nv = Engine.GetModelValue(model)
			if nv ~= nil then pcall(setRound, nv) end
		end)
	end)

	-- ===== time survived tile + leaderboard chip =============================
	local tileY = PANEL_Y + panelH + 16
	box(-110, 110, tileY, tileY + 54, COL_GLASS, 0.84)
	box(-110, 110, tileY, tileY + 2, COL_CYAN, 0.9)
	box(-110, 110, tileY + 52, tileY + 54, COL_CYAN, 0.9)
	label(-100, 100, tileY + 7, 13, 0.6, "TIME SURVIVED", COL_CYAN, 0.75, "c")
	local timeVal = label(-100, 100, tileY + 23, 24, 0.95, "-:--:--", COL_AMBER, 1, "c")
	local recChip = label(-260, 260, tileY + 62, 14, 0.62, "RUN SAVED - CITY LEADERBOARD UPDATED", COL_TEAL, 0, "c")

	-- ===== decision hint + countdown =========================================
	-- the actual choice lives in the pause menu (auto-opened by GSC); if the player
	-- backs out of it, the hint shows the way back in
	local hint   = label(-500, 500, 600, 15, 0.7, "CHOOSE IN THE MENU  -  PRESS [ESC / START] IF IT IS CLOSED", COL_TITLE, 0.7, "c")
	local footer = label(-500, 500, 624, 14, 0.65, "", COL_TEXT, 0.5, "c")

	-- ===== dvar poll: countdown + host info ==================================
	local infoApplied = false
	local lastExit = nil
	local ticks = 0

	if Hud.accGoTimer then Hud.accGoTimer:close() end
	Hud.accGoTimer = LUI.UITimer.new(150, "acc_go_tick", false)
	Hud:addElement(Hud.accGoTimer)
	Hud:registerEventHandler("acc_go_tick", function(element, event)
		ticks = ticks + 1

		-- stats settle: re-pull the scoreboard columns for the first ~3s (values are
		-- frozen at death, so polling forever buys nothing)
		if ticks <= 20 then
			for i = 1, rowCount do refreshRowStats(rows[i]) end
		end

		-- authoritative info from the host: "round|H:MM:SS|rec" (peers keep the
		-- client-side round + placeholder tile - dvars never replicate)
		if not infoApplied then
			local info = dvarStr("acc_go_info")
			if info ~= "" then
				infoApplied = true
				pcall(function()
					local f = split(info)
					if f[1] ~= nil then setRound(f[1]) end
					if f[2] ~= nil then timeVal:setText(f[2]) end
					recChip:setAlpha((f[3] == "1" and 0.8) or 0)
				end)
			end
		end

		local ex = dvarStr("acc_go_exit")
		if ex ~= "" and ex ~= lastExit then
			lastExit = ex
			local s = tonumber(ex) or 0
			footer:setText("NO CHOICE - AUTO END GAME IN " .. s .. "s")
			if s <= 10 then
				footer:setRGB(COL_AMBER[1], COL_AMBER[2], COL_AMBER[3])
				footer:setAlpha(0.9)
			else
				footer:setRGB(COL_TEXT[1], COL_TEXT[2], COL_TEXT[3])
				footer:setAlpha(0.5)
			end
		end
	end)

	-- GSC can close this menu at any moment - the poll timer dies with it (memory
	-- lui-uitimer-leaks-state-pool; OverrideFunction close hook = the stock pattern)
	LUI.OverrideFunction_CallOriginalSecond(Hud, "close", function(element)
		if element.accGoTimer then
			element.accGoTimer:close()
			element.accGoTimer = nil
		end
	end)

	-- ===== entrance ==========================================================
	tween(root, 400)
	root:setAlpha(1)

	return Hud
end
