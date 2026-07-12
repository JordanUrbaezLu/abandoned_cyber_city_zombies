-- acc_lb_rec_chunk.lua - INNER bytecode chunk: RECORD one finished game (docs/40).
--
-- hksc-compiled (tools/build_lb_lui.js) so io/os are legal here - L3akMod's source
-- whitelist never sees this file; it ships as a \ddd string inside the generated
-- ui/uieditor/menus/hud/acc_lb_rec.lua and runs via load(reader) (THE WORKING RECIPE).
--
-- Runs ONCE, on the recording client (players[0]), opened by _acc_leaderboard.gsc at
-- end_game - and NEVER when dev or god mode is on (user rule 2026-07-11: assisted runs
-- must not POST or store anything; GSC enforces it by not opening this menu).
--
-- Everything client-side (docs/40 bridge): roster from the PlayerList UI models
-- (AetheriumScoreboard read), round from gameScore.roundsPlayed (AetheriumStartMenu
-- displays raw-1 as the round; live-verified raw = round_number+1), timestamp/
-- session minted here with os.time. The POST itself is done by the background
-- agent (acc_lb_boot_chunk.lua) - this chunk only writes files, so game end never
-- spawns a console or blocks (the fullscreen tab-out fix). Progress breadcrumbs
-- ride Engine.Exec -> dvar acc_lb_rec_trace (v5a-proven bridge); GSC mirrors them
-- into console_mp.log.
--
-- @@ACC_LB_URL@@ / @@ACC_LB_KEY@@ / @@ACC_LB_MAPV@@ are spliced by build_lb_lui.js
-- from backend/leaderboard/deployed.local.json.

local mode, ctrl = ...

local URL = "@@ACC_LB_URL@@"

local trace = ""
local function T(tag)
	trace = trace .. tag .. "|"
	pcall(function()
		Engine.Exec(Engine.GetLocalClientNum(), 'set acc_lb_rec_trace "' .. trace .. '"')
	end)
end

-- gamertags go into a JSON FILE (never the command line - injection-proof) but keep
-- them delimiter-clean for our |-and-comma formats and the JSON string literal.
local function clean(s)
	s = tostring(s or "")
	s = string.gsub(s, "[%c\"'\\|,;]", " ")
	s = string.gsub(s, "^%s+", "")
	s = string.gsub(s, "%s+$", "")
	return string.sub(s, 1, 24)
end

local function model(path)
	local v = nil
	pcall(function()
		local c = ctrl
		if c == nil then c = Engine.GetLocalClientNum() end
		v = Engine.GetModelValue(Engine.GetModel(Engine.GetModelForController(c), path))
	end)
	return v
end

T("in")
local okEG = pcall(EnableGlobals)
T("eg" .. (okEG and "1" or "0"))

-- roster: up to 4 gamertags, client-side (docs/40 - no GSC string channel needed)
local names = {}
for i = 0, 3 do
	local n = model("PlayerList." .. i .. ".playerName")
	if n ~= nil and n ~= "" then
		local c = clean(n)
		if c ~= "" then names[#names + 1] = c end
	end
end
T("n" .. #names)

-- round: gameScore.roundsPlayed holds display-round + 1 (AetheriumStartMenu:426 shows
-- raw-1). raw==0 means the model read failed - abort rather than post garbage.
local raw = tonumber(model("gameScore.roundsPlayed")) or 0
local round = raw - 1
if round < 1 then round = 1 end
T("r" .. raw .. ">" .. round)

-- timestamp + session id. Minted HERE (one recorder = no cross-client agreement
-- needed); epoch seconds + table-address entropy is unique per game for our scale.
local ts = 0
pcall(function() ts = os.time() end)
ts = tonumber(ts) or 0
local ent = ""
pcall(function() ent = string.sub(string.gsub(tostring({}), "%W", ""), -6) end)
local session = "g" .. ts .. "-" .. ent
T("id" .. session)

if #names == 0 or raw == 0 then
	T("ABORT_bad_data")
	pcall(DisableGlobals)
	return trace
end

local csv = ""
for i = 1, #names do csv = csv .. (i > 1 and "," or "") .. names[i] end

-- 1) local record (the station's offline fallback): session|round|names_csv|ts
local okW = pcall(function()
	local f = io.open("players/acc_lb_records.txt", "a")
	f:write(session .. "|" .. round .. "|" .. csv .. "|" .. ts .. "\n")
	f:close()
end)
T("w" .. (okW and "1" or "0"))

-- 2) cloud POST - handed to the BACKGROUND AGENT (acc_lb_boot_chunk.lua), never
-- exec'd from the game: os.execute spawns a console that yanks exclusive
-- fullscreen + blocks the UI thread (the user-reported game-end tab-out/freeze).
-- We write the body, then the trigger file; the agent curls it off-process (and
-- being detached, it still lands even if the player quits the game-over screen).
if URL ~= "" then
	local okJ = pcall(function()
		local f = io.open("players/acc_lb_post.json", "w")
		local j = '{"session":"' .. session .. '","round":' .. round .. ',"ts":' .. ts ..
			',"map_version":"@@ACC_LB_MAPV@@","players":['
		for i = 1, #names do j = j .. (i > 1 and "," or "") .. '"' .. names[i] .. '"' end
		j = j .. "]}"
		f:write(j)
		f:close()
	end)
	T("j" .. (okJ and "1" or "0"))

	local okQ = pcall(function()
		local f = io.open("players/acc_lb_do_post.txt", "w")
		f:write("post\n")
		f:close()
	end)
	T("q" .. (okQ and "1" or "0"))
else
	T("no_url_local_only")
end

pcall(DisableGlobals)
T("done")
return trace
