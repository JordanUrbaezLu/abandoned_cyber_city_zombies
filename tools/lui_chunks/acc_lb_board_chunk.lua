-- acc_lb_board_chunk.lua - INNER bytecode chunk: FETCH + serve the top-10 board (docs/40).
--
-- hksc-compiled (tools/build_lb_lui.js), shipped as a \ddd string inside the generated
-- ui/uieditor/menus/hud/acc_lb_board.lua, run via load(reader). io/os legal here.
--
-- STATELESS between calls (the outer menu re-undumps it per tick) - all cross-call
-- state lives on disk in players/acc_lb_top10.txt. Modes (first vararg):
--   "go"    - truncate the result file + write the agent's GET trigger file (pure io -
--             the background agent from acc_lb_boot_chunk.lua runs the curl and appends
--             the ACCEOF_OK/ERR marker; the game spawns NO process here, which is the
--             fullscreen tab-out fix). Also snapshots gameScore.roundsPlayed into
--             acc_lb_round_raw (the dev probe's round-offset oracle, harmless live).
--   "read"  - poll the file. Marker present -> parse "round|names" rows, push them to
--             dvars acc_lb_r1..r10 + acc_lb_done (Engine.Exec bridge; the GSC side
--             renders the card). Returns "done" / "neterr" / "again".
--   "local" - offline fallback: build the board from players/acc_lb_records.txt
--             (games recorded on THIS machine), same dvar contract, done="loc:N".
--
-- Names in server rows are already delimiter-safe (the Worker's cleanName strips
-- | , " \ and control chars); we belt-and-braces sanitize before Exec anyway.

local mode = ...

local URL = "@@ACC_LB_URL@@"
local RES = "players/acc_lb_top10.txt"

local function X(cmd)
	pcall(function() Engine.Exec(Engine.GetLocalClientNum(), cmd) end)
end
local function T(tag)
	X('set acc_lb_board_trace "' .. tostring(mode) .. ":" .. tag .. '"')
end

pcall(EnableGlobals)

if mode == "go" then
	pcall(function()
		local f = io.open(RES, "w")
		f:write("")
		f:close()
	end)
	-- round-model snapshot for the dev offset probe (docs/40)
	local raw = "?"
	pcall(function()
		raw = tostring(Engine.GetModelValue(Engine.GetModel(
			Engine.GetModelForController(Engine.GetLocalClientNum()), "gameScore.roundsPlayed")))
	end)
	X('set acc_lb_round_raw "' .. raw .. '"')

	if URL == "" then
		-- no backend baked in: mark the fetch failed so the outer falls to "local"
		pcall(function()
			local f = io.open(RES, "w")
			f:write("ACCEOF_ERR\n")
			f:close()
		end)
		T("no_url")
		pcall(DisableGlobals)
		return "went"
	end

	-- Hand the GET to the BACKGROUND AGENT (acc_lb_boot_chunk.lua) via its trigger
	-- file - never os.execute from gameplay: the spawned console yanks exclusive
	-- fullscreen (the user-reported interact tab-out). The agent writes RES + the
	-- ACCEOF_OK/ERR marker exactly as before, so "read" below is unchanged.
	local ok = pcall(function()
		local f = io.open("players/acc_lb_do_get.txt", "w")
		f:write("get\n")
		f:close()
	end)
	T(ok and "q1" or "q0")
	pcall(DisableGlobals)
	return "went"
end

local function push_rows(text, src)
	local n = 0
	for line in string.gmatch(text or "", "[^\r\n]+") do
		local r, names = string.match(line, "^(%d+)|(.*)$")
		if r ~= nil and n < 10 then
			n = n + 1
			local safe = string.gsub(names or "", "[%c\"';]", " ")
			X('set acc_lb_r' .. n .. ' "' .. r .. "|" .. string.sub(safe, 1, 80) .. '"')
		end
	end
	X('set acc_lb_done "' .. src .. ":" .. n .. '"')
	return n
end

if mode == "read" then
	local body = nil
	pcall(function()
		local f = io.open(RES, "r")
		if f ~= nil then
			body = f:read("*a")
			f:close()
		end
	end)
	if body == nil or body == "" then
		T("wait")
		pcall(DisableGlobals)
		return "again"
	end
	if string.find(body, "ACCEOF_ERR", 1, true) ~= nil then
		T("neterr")
		pcall(DisableGlobals)
		return "neterr"
	end
	if string.find(body, "ACCEOF_OK", 1, true) == nil then
		T("wait")
		pcall(DisableGlobals)
		return "again"
	end
	-- the Worker body has no trailing newline, so cmd's `echo ACCEOF_OK>>` glues the
	-- marker onto the last row (seen live: "NetRunner,ChromeACCEOF_OK") - strip both
	-- markers before parsing rows.
	body = string.gsub(body, "ACCEOF_OK", "")
	body = string.gsub(body, "ACCEOF_ERR", "")
	local n = push_rows(body, "net")
	T("done" .. n)
	pcall(DisableGlobals)
	return "done"
end

if mode == "local" then
	local rows = {}
	pcall(function()
		local f = io.open("players/acc_lb_records.txt", "r")
		if f ~= nil then
			local all = f:read("*a")
			f:close()
			for line in string.gmatch(all or "", "[^\r\n]+") do
				local r, csv = string.match(line, "^[^|]+|(%d+)|([^|]*)|")
				if r ~= nil then rows[#rows + 1] = { r = tonumber(r), names = csv } end
			end
		end
	end)
	pcall(function() table.sort(rows, function(a, b) return a.r > b.r end) end)
	local text = ""
	for i = 1, #rows do
		if i > 10 then break end
		text = text .. rows[i].r .. "|" .. rows[i].names .. "\n"
	end
	local n = push_rows(text, "loc")
	T("local" .. n)
	pcall(DisableGlobals)
	return "done"
end

pcall(DisableGlobals)
return "badmode"
