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
--             Dvar acc_lb_use_cache=1 (GSC, same-session same-lobby-size re-open) skips
--             the truncate+trigger: the on-disk result file IS the cache and the first
--             "read" tick serves it instantly, zero curl.
--   "read"  - poll the file. Marker present -> parse "round|names|stats" v2 rows, push
--             the legacy "round|names" dvars acc_lb_r1..r10 + acc_lb_done (Engine.Exec
--             bridge; the GSC fallback card renders those) and RETURN the structured
--             rows table {src, show, rows, tot} for the outer menu's LUI panel
--             (per-player kills/downs/revives UI + the map-wide totals footer,
--             2026-07-15). Returns "again"/"neterr" while pending/failed.
--   "local" - offline fallback: build the board from players/acc_lb_records.txt
--             (games recorded on THIS machine), same dvar + return-table contract.
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

-- Robust dvar READ (same forms as acc_lb_rec_chunk; the exact T7 signature is
-- unproven so try each, first non-empty wins, all pcall-guarded). Used to read
-- acc_lb_players (the GSC publishes the lobby size before opening this menu) so the
-- GET fetches the matching solo/duo/trio/quad ladder. Empty -> global board.
local function readdvar(name)
	local c = nil
	pcall(function() c = Engine.GetLocalClientNum() end)
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

pcall(EnableGlobals)

if mode == "go" then
	-- CACHED RE-OPEN (2026-07-15): GSC sets acc_lb_use_cache 1 when THIS lobby size's
	-- board already fetched this session - the result file still on disk (marker and
	-- all) is the cache; skip the truncate + agent trigger and let "read" serve it.
	if readdvar("acc_lb_use_cache") == "1" then
		T("cache")
		pcall(DisableGlobals)
		return "went"
	end
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
	-- PER-LOBBY-SIZE LADDER - THE REQUIREMENT (user 2026-07-15 round 3: "I should see
	-- top 10 solo rounds" when solo; briefly global that same day, reverted).
	-- DVAR FIRST (ladder-mismatch fix 2026-07-17, user: "quads leaderboard was showing
	-- duos"): acc_lb_players IS the server truth - GSC publishes GetPlayers().size right
	-- before every fetch open, and fetches only ever run on the HOST, where the dvar
	-- round-trips. The old order counted the PlayerList models FIRST, but those slots can
	-- be unresolved/stale mid-game (the rec chunk's documented hazard), so a quad could
	-- count 2 resolved names and fetch the DUO ladder under a QUADS title. The client-side
	-- count stays as the fallback for an empty dvar read, then the global board. v2 = ONE
	-- param carrying both the format marker and the count (?v2=N, 0=global) so the agent's
	-- delayed-expansion suffix never needs '&' (build_lb_lui.js splice guard); Worker
	-- appends "|name:kills:downs:revives,..." per game.
	local pc = tonumber(readdvar("acc_lb_players")) or 0
	if pc < 1 then
		pcall(function()
			local c = Engine.GetLocalClientNum()
			for i = 0, 3 do
				local nm = Engine.GetModelValue(Engine.GetModel(Engine.GetModelForController(c), "PlayerList." .. i .. ".playerName"))
				if nm ~= nil and tostring(nm) ~= "" then pc = pc + 1 end
			end
		end)
	end
	local q = "?v2=0"
	if pc >= 1 and pc <= 4 then q = "?v2=" .. pc end
	local ok = pcall(function()
		local f = io.open("players/acc_lb_do_get.txt", "w")
		f:write(q .. "\n")
		f:close()
	end)
	T(ok and ("q1_" .. pc) or "q0")
	pcall(DisableGlobals)
	return "went"
end

-- "round|names|stats" text (v2; the stats field is optional - v1 rows and old local
-- records simply have none) -> rows table for the outer's LUI panel:
--   { r=round, w=paradise_winner, names="a,b", st={ {n=name,k=kills,d=downs,rv=revives}, ... } }
-- Second return = the optional v2 TOTALS footer "T|<games>|<wins>" (Worker, 2026-07-15)
-- -> { g=games_played, w=paradise_wins }, nil when absent (v1 body / local records).
local function parse_rows(text)
	local rows = {}
	local tot = nil
	for line in string.gmatch(text or "", "[^\r\n]+") do
		-- footer first: it starts with "T", data rows start with the round digits, so the
		-- two shapes can never be confused (and an old body simply has no footer)
		-- unanchored tail (no `$`): the agent .bat's `echo ACCEOF_OK>>` glues the marker
		-- onto this line (it is the LAST one) and a stray \r / space must not defeat it
		local tg, tw = string.match(line, "^T|(%d+)|(%d+)")
		if tg ~= nil then
			tot = { g = tonumber(tg) or 0, w = tonumber(tw) or 0 }
		end
		local r, rest = string.match(line, "^(%d+)|(.*)$")
		if r ~= nil and #rows < 10 then
			local names, st = string.match(rest, "^([^|]*)|(.*)$")
			if names == nil then
				names = rest
				st = ""
			end
			-- "* " prefix = Paradise-winner run (Worker convention 2026-07-13)
			local w = false
			if string.sub(names, 1, 2) == "* " then
				w = true
				names = string.sub(names, 3)
			end
			local stats = {}
			-- same 4-field shape as the acc_lb_stats dvar / rec-chunk POST: a malformed
			-- field can't half-match, so junk degrades to "no stats", never a bad row
			for nm, k, d, rv in string.gmatch(st or "", "([^:,]+):(%d+):(%d+):(%d+)") do
				stats[#stats + 1] = { n = nm, k = tonumber(k) or 0, d = tonumber(d) or 0, rv = tonumber(rv) or 0 }
			end
			rows[#rows + 1] = { r = tonumber(r) or 0, w = w, names = names, st = stats }
		end
	end
	return rows, tot
end

-- legacy dvar push (unchanged format "round|names", star prefix preserved) - the GSC
-- fallback card + dev probe logging still read these; the LUI panel reads the TABLE.
-- CO-OP PEER RELAY (2026-07-16, user: "non host players cant see the UI for the
-- Leaderboards"): ALSO push each row's per-player stats (acc_lb_st<i>) + the totals
-- footer (acc_lb_tot). On the HOST these Exec-sets land in the SERVER dvar table, so
-- GSC can relay the full v2 board to a co-op peer over controller UI models (the
-- accLbR*/accLbTot/accLbSrc push in _acc_leaderboard::show_board_peer) - the peer's
-- machine has no agent, no local records and never sees server SetDvars, so this
-- relay is its ONLY data path. "feed" mode below is the peer-side reader.
local function push_rows(rows, src, tot)
	for i = 1, #rows do
		local names = rows[i].names
		if rows[i].w then names = "* " .. names end
		local safe = string.gsub(names or "", "[%c\"';]", " ")
		X('set acc_lb_r' .. i .. ' "' .. rows[i].r .. "|" .. string.sub(safe, 1, 80) .. '"')
		local st = rows[i].st or {}
		local blob = ""
		for j = 1, #st do
			if blob ~= "" then blob = blob .. "," end
			blob = blob .. string.gsub(tostring(st[j].n), "[%c\"';]", " ") .. ":" .. st[j].k .. ":" .. st[j].d .. ":" .. st[j].rv
		end
		X('set acc_lb_st' .. i .. ' "' .. string.sub(blob, 1, 200) .. '"')
	end
	if tot ~= nil then
		X('set acc_lb_tot "' .. tostring(tot.g) .. "|" .. tostring(tot.w) .. '"')
	end
	X('set acc_lb_done "' .. src .. ":" .. #rows .. '"')
end

-- The outer renders the panel only when GSC asked for a visible board. Unset/empty
-- (e.g. a co-op peer whose client never sees server dvars) defaults to SHOW - the
-- silent fetch paths (auto_fetch_board / dev probe) are host-only, where the dvar
-- round-trips and is explicitly "0".
local function show_flag()
	return readdvar("acc_lb_board_show") ~= "0"
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
	local rows, tot = parse_rows(body)
	push_rows(rows, "net", tot)
	T("done" .. #rows)
	local res = { src = "net", show = show_flag(), rows = rows, tot = tot }
	pcall(DisableGlobals)
	return res
end

if mode == "local" then
	local raw = {}
	pcall(function()
		local f = io.open("players/acc_lb_records.txt", "r")
		if f ~= nil then
			local all = f:read("*a")
			f:close()
			-- DEDUP BY SESSION (per-round records, 2026-07-18): the rec chunk now appends a
			-- line at EVERY round start (+ baseline/Paradise-win/leave-flush/end_game), all
			-- carrying the same session id. The Worker upserts those into ONE row; this
			-- offline lane must too, or a single 40-round game fills the whole board. Keep
			-- the HIGHEST round per session; on a tie keep the LATER line (freshest stats).
			local bySession = {}
			for line in string.gmatch(all or "", "[^\r\n]+") do
				-- new lines: session|round|names|ts|stats ; old lines: session|round|names|ts
				local sid, r, csv, st = string.match(line, "^([^|]+)|(%d+)|([^|]*)|[^|]*|(.*)$")
				if r == nil then
					sid, r, csv = string.match(line, "^([^|]+)|(%d+)|([^|]*)|")
					st = ""
				end
				if r ~= nil and sid ~= nil then
					local n = tonumber(r)
					local cur = bySession[sid]
					if cur == nil then
						cur = { r = n, names = csv, st = st }
						bySession[sid] = cur
						raw[#raw + 1] = cur   -- same table ref: later upserts mutate in place
					elseif n >= cur.r then
						cur.r = n
						cur.names = csv
						cur.st = st
					end
				end
			end
		end
	end)
	pcall(function() table.sort(raw, function(a, b) return a.r > b.r end) end)
	local text = ""
	for i = 1, #raw do
		if i > 10 then break end
		text = text .. raw[i].r .. "|" .. raw[i].names .. "|" .. (raw[i].st or "") .. "\n"
	end
	local rows = parse_rows(text)
	push_rows(rows, "loc")
	T("local" .. #rows)
	-- NO totals footer offline (tot stays nil -> the outer draws no line): the records
	-- file holds only THIS machine's games and never stored the Paradise flag, so any
	-- "N/M reached the bottom" built from it would be a wrong claim about a global stat.
	local res = { src = "loc", show = show_flag(), rows = rows }
	pcall(DisableGlobals)
	return res
end

-- CO-OP PEER LANE: rebuild the board from the controller UI models GSC relayed
-- (_acc_leaderboard::show_board_peer pushes accLbR1..accLbR10 = "round|names|stats",
-- accLbTot = "games|wins", accLbSrc = "net"/"loc" - the server dvar rows from the
-- HOST's last fetch, replicated per-player by SetControllerUIModelValue; the
-- docs/16 Wonderfizz bridge). A peer machine has no agent and no records file, so
-- this is the only lane with data there. Returns "none" when the relay is empty
-- (host never fetched) so the outer falls through to the usual local fallback.
if mode == "feed" then
	local function readmodel(name)
		local v = nil
		pcall(function()
			v = Engine.GetModelValue(Engine.GetModel(Engine.GetModelForController(Engine.GetLocalClientNum()), name))
		end)
		-- string values only: an empty slot reads nil (or a userdata ref - the
		-- PlayerList lesson, memory lb-playername-localize-not-tostring)
		if type(v) ~= "string" then return "" end
		return v
	end
	local text = ""
	for i = 1, 10 do
		local row = readmodel("accLbR" .. i)
		if row ~= "" then text = text .. row .. "\n" end
	end
	local totS = readmodel("accLbTot")
	if totS ~= "" then text = text .. "T|" .. totS .. "\n" end
	local rows, tot = parse_rows(text)
	if #rows == 0 and tot == nil then
		T("feed0")
		pcall(DisableGlobals)
		return "none"
	end
	local src = readmodel("accLbSrc")
	if src ~= "net" then src = "loc" end
	T("feed" .. #rows)
	local res = { src = src, show = show_flag(), rows = rows, tot = tot }
	pcall(DisableGlobals)
	return res
end

pcall(DisableGlobals)
return "badmode"
