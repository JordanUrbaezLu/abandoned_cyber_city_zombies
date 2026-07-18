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

local function X(cmd)
	pcall(function() Engine.Exec(Engine.GetLocalClientNum(), cmd) end)
end

-- DURABLE breadcrumb (2026-07-17 outage fix): the dvar trace dies with the session and a
-- plain Steam launch has no console_mp.log - append the full trace to disk at every exit so
-- a lost game is always post-mortemable from players\acc_lb_rec_log.txt.
local function FL(s)
	pcall(function()
		local t = 0
		pcall(function() t = os.time() end)
		local f = io.open("players/acc_lb_rec_log.txt", "a")
		f:write(tostring(t) .. " " .. s .. "\n")
		f:close()
	end)
end

-- gamertags go into a JSON FILE (never the command line - injection-proof) but keep
-- them delimiter-clean for our |-and-comma formats and the JSON string literal.
-- GUARD (name-capture glitch fix, 2026-07-14): a playerName model value is NOT always a
-- Lua string - it can arrive as a userdata reference to a localized-string entry, and
-- tostring() on that yields the raw handle "userdata: 0000..." which was landing in the DB
-- as a gamertag (see summary.js suspiciousName + docs/40). resolve_name() below runs the
-- value through Engine.Localize (what the scoreboard does, AetheriumScoreboard:468) FIRST,
-- so clean() only ever sees a real string; as a last line of defence clean() also drops
-- any residual "userdata:"-prefixed value rather than storing a handle.
local function clean(s)
	if type(s) ~= "string" then return "" end   -- userdata/number/nil -> never a raw handle
	if string.match(s, "^userdata:") then return "" end
	s = string.gsub(s, "[%c\"'\\|,;]", " ")
	s = string.gsub(s, "^%s+", "")
	s = string.gsub(s, "%s+$", "")
	return string.sub(s, 1, 24)
end

-- playerName resolves through Engine.Localize (a plain gamertag passes through unchanged;
-- a userdata localized-string ref becomes its string). Anything that does not resolve to a
-- string is dropped by returning "" so it is never captured as a name.
local function resolve_name(v)
	if v == nil then return "" end
	if type(v) == "string" then return v end
	local out = nil
	pcall(function() out = Engine.Localize(v) end)
	if type(out) == "string" then return out end
	return ""
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

-- Robust dvar READ (docs/41 weapon-usage transport). NO LUI in this repo read a dvar
-- before, so the exact T7 signature is unproven - try the plausible forms and use the
-- first that yields non-empty; every form is pcall-guarded so a nil Engine.* just
-- falls through. Empty result -> the field is simply omitted from the POST (graceful:
-- the game still records fine; gun stats just stay empty until the read is supported).
local function readdvar(name)
	local c = ctrl
	if c == nil then pcall(function() c = Engine.GetLocalClientNum() end) end
	local forms = {
		function() return Engine.DvarString(c, name) end,
		function() return Engine.DvarString(name) end,
		function() return Engine.GetDvarString(c, name) end,
		function() return Engine.GetDvarString(name) end,
		function() return Engine.GetDvar(name) end,
	}
	for i = 1, #forms do
		local ok, v = pcall(forms[i])
		if ok and v ~= nil and tostring(v) ~= "" then return tostring(v) end
	end
	return ""
end

T("in")
local okEG = pcall(EnableGlobals)
T("eg" .. (okEG and "1" or "0"))

-- roster: up to 4 gamertags, client-side (docs/40 - no GSC string channel needed)
-- OCCUPANCY and NAME are two DIFFERENT questions (ladder fix 2026-07-15). The slot test here is
-- byte-for-byte the BOARD chunk's (acc_lb_board_chunk.lua: `nm ~= nil and tostring(nm) ~= ""`),
-- which stock GetPlayers().size agrees with - so a userdata playerName COUNTS as a player. It has
-- to: an EMPTY slot yields nil/"" (proof: 97 solo games recorded exactly ONE name under that same
-- pre-Localize guard), so a userdata is a REAL teammate whose tag merely failed to resolve.
-- Dropping him shrank the roster, and the ENTRY COUNT is how lobby size is stored - the Worker
-- recovers it as (commas + 1) - so a quad filed under the TRIO ladder while its own board asked
-- ?v2=4 and never saw itself. Keep the slot, scrub only the unrecoverable NAME to "?": the exact
-- lesson of the 2026-07-14 data repair (memory lb-playername-localize-not-tostring - "NEVER change
-- the entry count"), and "?" is what those repaired rows already carry, so the board renders it.
local names = {}
for i = 0, 3 do
	local v = model("PlayerList." .. i .. ".playerName")
	if v ~= nil and tostring(v) ~= "" then
		local c = clean(resolve_name(v))
		if c == "" then c = "?" end   -- occupied slot, unrecoverable tag: hold the place
		names[#names + 1] = c
	end
end
T("n" .. #names)

-- round: gameScore.roundsPlayed holds display-round + 1 (AetheriumStartMenu:426 shows
-- raw-1). raw==0 means the model read failed - abort rather than post garbage.
local raw = tonumber(model("gameScore.roundsPlayed")) or 0
local round = raw - 1
if round < 1 then round = 1 end
T("r" .. raw .. ">" .. round)

-- timestamp + session id. Minted HERE on the FIRST record of the match (one recorder = no
-- cross-client agreement needed); epoch seconds + table-address entropy is unique per game
-- for our scale. SESSION REUSE (2026-07-17): the minted id is parked on the acc_lb_session
-- dvar (GSC clears it every load) so a SECOND record this match - the Paradise win-time
-- record followed by the final end_game one - POSTs the same session and the Worker's
-- dedup-by-session upsert lands them as ONE game at the highest round.
local ts = 0
pcall(function() ts = os.time() end)
ts = tonumber(ts) or 0
local session = readdvar("acc_lb_session")
if session == "" then
	local ent = ""
	pcall(function() ent = string.sub(string.gsub(tostring({}), "%W", ""), -6) end)
	session = "g" .. ts .. "-" .. ent
	X('set acc_lb_session "' .. session .. '"')
end
T("id" .. session)

if #names == 0 or raw == 0 then
	T("ABORT_bad_data")
	FL("ABORT " .. trace)
	pcall(DisableGlobals)
	return trace
end

local csv = ""
for i = 1, #names do csv = csv .. (i > 1 and "," or "") .. names[i] end

-- per-player stats blob "name:kills:downs:revives,..." (docs/40) - read HERE (not just in
-- the POST branch) so the machine-local record carries it too and the offline board shows
-- the same kills/downs/revives columns as the cloud one (board UI 2026-07-15).
local pstats = readdvar("acc_lb_stats")

-- 1) local record (the station's offline fallback): session|round|names_csv|ts|stats
-- (the stats field is NEW 2026-07-15; the board chunk's local parser accepts both the
-- old 4-field and this 5-field shape)
local okW = pcall(function()
	local f = io.open("players/acc_lb_records.txt", "a")
	f:write(session .. "|" .. round .. "|" .. csv .. "|" .. ts .. "|" .. pstats .. "\n")
	f:close()
end)
T("w" .. (okW and "1" or "0"))

-- 2) cloud POST - handed to the BACKGROUND AGENT (acc_lb_boot_chunk.lua), never
-- exec'd from the game: os.execute spawns a console that yanks exclusive
-- fullscreen + blocks the UI thread (the user-reported game-end tab-out/freeze).
-- We write the body, then the trigger file; the agent curls it off-process (and
-- being detached, it still lands even if the player quits the game-over screen).
if URL ~= "" then
	-- gun-usage blob (docs/41): "id:secs,id:secs" the GSC published on acc_lb_guns +
	-- the game duration for the server sanity clamp. Empty when the dvar read is
	-- unsupported OR the sampler tracked nothing (dev/god) -> both fields omitted.
	local guns = readdvar("acc_lb_guns")
	local dur = tonumber(readdvar("acc_lb_dur")) or 0
		local paradise = readdvar("acc_lb_paradise")   -- "1" = beat Paradise this run (docs/40 winner tag)
	local box = readdvar("acc_lb_box")   -- "id:offers:takes,..." box telemetry (docs/41 Tier B)
	local drop = readdvar("acc_lb_drop")   -- "id:acquires:replaced,..." retention telemetry (docs/41 Tier C)
	-- pstats ("name:kills:downs:revives,...") already read above for the local record
	T("gl" .. #guns)

	local okJ = pcall(function()
		local f = io.open("players/acc_lb_post.json", "w")
		local j = '{"session":"' .. session .. '","round":' .. round .. ',"ts":' .. ts ..
			',"map_version":"@@ACC_LB_MAPV@@"'
		if dur > 0 then j = j .. ',"duration_secs":' .. dur end
			if paradise == "1" then j = j .. ',"paradise_winner":true' end
		j = j .. ',"players":['
		for i = 1, #names do j = j .. (i > 1 and "," or "") .. '"' .. names[i] .. '"' end
		j = j .. "]"
		if guns ~= "" then
			j = j .. ',"guns":['
			local first = true
			for id, secs in string.gmatch(guns, "(%d+):(%d+)") do
				j = j .. (first and "" or ",") .. '{"id":' .. id .. ',"secs":' .. secs .. '}'
				first = false
			end
			j = j .. "]"
		end
		if box ~= "" then
			-- box telemetry (docs/41 Tier B): "id:offers:takes" triples. The 3-capture
			-- gmatch can NOT half-match a guns-style pair, so a wrong/stale dvar read
			-- degrades to an empty array, never corrupt JSON.
			j = j .. ',"box":['
			local first = true
			for id, off, tk in string.gmatch(box, "(%d+):(%d+):(%d+)") do
				j = j .. (first and "" or ",") .. '{"id":' .. id .. ',"offers":' .. off .. ',"takes":' .. tk .. '}'
				first = false
			end
			j = j .. "]"
		end
		if drop ~= "" then
			-- retention telemetry (docs/41 Tier C): "id:acquires:replaced" triples. Same
			-- 3-capture gmatch guard as box -> a malformed/stale read degrades to an empty
			-- array, never corrupt JSON (a guns-style pair can't half-match a triple).
			j = j .. ',"drop":['
			local first = true
			for id, aq, rp in string.gmatch(drop, "(%d+):(%d+):(%d+)") do
				j = j .. (first and "" or ",") .. '{"id":' .. id .. ',"acq":' .. aq .. ',"rep":' .. rp .. '}'
				first = false
			end
			j = j .. "]"
		end
		if pstats ~= "" then
			-- per-player stats (docs/40): "name:kills:downs:revives" records. The name was
			-- delimiter-scrubbed in GSC (StrTok dropped ':' ',' '"' '\\' ...), so it is safe to
			-- embed verbatim in the JSON string AND the [^:,]+ capture can't run past a record
			-- boundary. A malformed/stale read that doesn't match the 4-field shape degrades to
			-- an empty array, never corrupt JSON.
			j = j .. ',"stats":['
			local first = true
			for nm, k, d, r in string.gmatch(pstats, "([^:,]+):(%d+):(%d+):(%d+)") do
				j = j .. (first and "" or ",") .. '{"name":"' .. nm .. '","kills":' .. k ..
					',"downs":' .. d .. ',"revives":' .. r .. '}'
				first = false
			end
			j = j .. "]"
		end
		j = j .. "}"
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

T("done")
FL(trace)
pcall(DisableGlobals)
return trace
