-- acc_lb_boot_chunk.lua - INNER bytecode chunk: OPT-IN CONSENT + spawn the AGENT (docs/40).
--
-- THE FULLSCREEN TAB-OUT FIX, v2 = OPT-IN (user 2026-07-13). os.execute from LUI spawns a
-- console window that yanks exclusive fullscreen (the "it tabs us out / looks like the map
-- is hacking me" report). v1 hid it (WSH SW_HIDE agent) but still fired os.execute at EVERY
-- match start for EVERY player. v2 makes the whole thing OPT-IN and default OFF:
--   * players/acc_lb_consent.txt  "1"=opted in, "0"=declined, absent=undecided.
--   * a player who never opts in spawns NOTHING - no console, no tab-out, ever.
--   * even an opted-in player no longer spawns at blackscreen: the agent is spawned at
--     END_GAME instead (GSC opens this chunk in "spawn" mode there), where a console flash is
--     invisible on the game-over screen. So opted-in players get ZERO gameplay-time console.
--   * the ONE moment os.execute runs during play is right after the player deliberately holds
--     [Melee] to enable (mode "set1") - an expected flash on their own action.
--
-- MODE is read from the dvar acc_lb_boot_cmd (GSC sets it before OpenLUIMenu; the v5a
-- Exec<->dvar bridge round-trips on the host/solo listen server). Default = "check".
--   "check": read consent -> Exec set acc_lb_consent <1|0|none> for GSC. NEVER spawns.
--   "set1" : force consent "1" -> spawn the agent NOW -> Exec set acc_lb_consent "1".
--   "set0" : write consent "0" (NEVER clobber an existing "1") -> Exec the current value.
--   "spawn": spawn the agent, touch no file (dev auto-spawn + the end_game spawn).
--
-- Once spawned, the agent (players\acc_lb_agent_<tok>.bat) polls ~1s until BlackOps3.exe
-- exits (game-liveness watch, 2026-07-15 - ~8h cap as backstop) then self-deletes; ALL
-- later network work is just TRIGGER FILES the rec/board chunks write
-- (pure io, no process) - the agent serves them off-process:
--   players\acc_lb_do_post.txt -> curl POST acc_lb_post.json -> acc_lb_post_result.txt
--   players\acc_lb_do_get.txt  -> curl GET top10 -> acc_lb_top10.txt + ACCEOF marker
--   players\acc_lb_ping.txt    -> del + echo pong>acc_lb_pong.txt  (liveness; the launcher
--                                 pre-spawn uses this to skip a duplicate - run_game.ps1)
--
-- KNOWN-SAFE SHAPE (do not "improve" without an in-game load test): all io/os work happens
-- SYNCHRONOUSLY in createMenu. NEVER os.execute from a UITimer callback (2026-07-12: two clean
-- loads FROZE THE ENGINE). NEVER overwrite a RUNNING .bat (cmd re-reads it from disk) ->
-- per-boot token filename. `ping -n 2` = the ~1s batch sleep (timeout needs stdin).

local mode0, ctrl = ...

local URL = "@@ACC_LB_URL@@"
local KEY = "@@ACC_LB_KEY@@"
local CONSENT = "players/acc_lb_consent.txt"

local function X(cmd)
	pcall(function() Engine.Exec(Engine.GetLocalClientNum(), cmd) end)
end

-- Robust dvar READ (same forms as the board/rec chunks; the exact T7 signature is unproven,
-- so try each and take the first non-empty - every form pcall-guarded). Reads acc_lb_boot_cmd.
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

-- consent file: "1"=opted in, "0"=declined, "none"=undecided (absent). io -> EnableGlobals first.
local function read_consent()
	local v = nil
	pcall(function()
		local f = io.open(CONSENT, "r")
		if f ~= nil then v = f:read("*a") f:close() end
	end)
	if v == nil then return "none" end
	if string.find(v, "1", 1, true) ~= nil then return "1" end
	if string.find(v, "0", 1, true) ~= nil then return "0" end
	return "none"
end

local function write_consent(val)
	pcall(function()
		local f = io.open(CONSENT, "w")
		f:write(val .. "\n")
		f:close()
	end)
end

-- Spawn the hidden background agent. UNCHANGED recipe from v1 (WSH SW_HIDE trampoline: the
-- .vbs does WScript.Shell.Run(bat, 0, False) = window never shown; the .vbs self-deletes; the
-- only residual artifact is os.execute's own sub-second cmd flash, now only ever at end_game /
-- on a deliberate opt-in). Caller must have called EnableGlobals(). Returns true if launched.
local function spawn_agent()
	local tok = ""
	pcall(function() tok = string.sub(string.gsub(tostring({}), "%W", ""), -6) end)
	if tok == "" then tok = "A" end
	local bat = "players/acc_lb_agent_" .. tok .. ".bat"

	-- Clear a stale GET trigger (an old query re-fired would just waste a curl). The POST
	-- trigger is deliberately KEPT (2026-07-17 outage fix): if the previous session's agent
	-- never came up, its recorded game is still queued in acc_lb_do_post.txt +
	-- acc_lb_post.json - the fresh agent SENDS it, self-healing the pipeline. Re-sending is
	-- safe: the Worker dedups by session id (upsert, MAX round).
	pcall(function() os.remove("players/acc_lb_do_get.txt") end)

	-- GAME-LIVENESS EXIT (2026-07-15, the Steam stuck-at-"Stopping" fix): THIS agent is an os.execute
	-- descendant of BlackOps3.exe, i.e. inside the process tree Steam watches - while it lives, Steam
	-- shows the game "Stopping" until Steam itself is restarted (it used to run the full ~8h loop
	-- unconditionally). Every ~10s it checks tasklist for BlackOps3.exe: once the game has been SEEN and
	-- then GONE for 2 consecutive checks (~20-30s) it exits + self-deletes; never-seen within ~200s also
	-- exits. The 28800 (~8h) cap stays as a backstop. KEEP IN LOCKSTEP with spawn_lb_agent.tpl.ps1.
	local lines = {
		"@echo off",
		"setlocal EnableDelayedExpansion",
		"rem ACC leaderboard agent - generated by the game on opt-in / at end_game (docs/40).",
		"rem Runs curl OFF the game process so play never spawns a console window.",
		'cd /d "%~dp0"',
		"set /a ACCT=0",
		"set /a ACCSEEN=0",
		"set /a ACCGONE=0",
		"for /l %%i in (1,1,28800) do (",
		"  if exist acc_lb_ping.txt (",
		"    del acc_lb_ping.txt >nul 2>&1",
		"    echo pong>acc_lb_pong.txt",
		"  )",
		"  if exist acc_lb_do_post.txt (",
		"    del acc_lb_do_post.txt >nul 2>&1",
		'    curl.exe -s -m 6 -X POST -H "content-type: application/json" -H "x-acc-key: ' .. KEY .. '" --data @acc_lb_post.json -o acc_lb_post_result.txt ' .. URL .. '/games',
		"  )",
		"  if exist acc_lb_do_get.txt (",
		'    set "ACCQ="',
		"    set /p ACCQ=<acc_lb_do_get.txt",
		"    del acc_lb_do_get.txt >nul 2>&1",
		"    curl.exe -s -m 5 -o acc_lb_top10.txt " .. URL .. "/top10.txt!ACCQ! && echo ACCEOF_OK>>acc_lb_top10.txt || echo ACCEOF_ERR>>acc_lb_top10.txt",
		"  )",
		"  set /a ACCT+=1",
		"  if !ACCT! geq 10 (",
		"    set /a ACCT=0",
		'    tasklist /fi "IMAGENAME eq BlackOps3.exe" 2>nul | find /i "BlackOps3.exe" >nul 2>&1',
		"    if not errorlevel 1 (",
		"      set /a ACCSEEN=1",
		"      set /a ACCGONE=0",
		"    ) else (",
		"      set /a ACCGONE+=1",
		"      if !ACCSEEN! geq 1 if !ACCGONE! geq 2 goto accbye",
		"      if !ACCSEEN! leq 0 if !ACCGONE! geq 20 goto accbye",
		"    )",
		"  )",
		"  ping -n 2 127.0.0.1 >nul",
		")",
		":accbye",
		'del "%~f0"',
	}
	local okW = pcall(function()
		local f = io.open(bat, "w")
		local s = ""
		for i = 1, #lines do s = s .. lines[i] .. "\r\n" end
		f:write(s)
		f:close()
	end)
	if not okW then return false end

	-- INVISIBLE spawn via a WSH trampoline (WScript.Shell.Run(...,0,...) = SW_HIDE = the agent
	-- console is never shown; no window, no taskbar item, Task-Manager only). The .vbs derives
	-- the bat path from its own folder (cwd-independent) and self-deletes. If WSH is
	-- policy-disabled the agent just never starts and the board falls back to offline.
	local vbs = "players/acc_lb_launch_" .. tok .. ".vbs"
	local okV = pcall(function()
		local f = io.open(vbs, "w")
		f:write('On Error Resume Next\r\n')
		f:write('Set fso = CreateObject("Scripting.FileSystemObject")\r\n')
		f:write('Set sh = CreateObject("WScript.Shell")\r\n')
		f:write('dir = fso.GetParentFolderName(WScript.ScriptFullName)\r\n')
		f:write('sh.CurrentDirectory = dir\r\n')
		f:write('bat = fso.BuildPath(dir, "acc_lb_agent_' .. tok .. '.bat")\r\n')
		f:write('sh.Run """" & bat & """", 0, False\r\n')
		f:write('fso.DeleteFile WScript.ScriptFullName\r\n')
		f:close()
	end)
	if not okV then return false end
	local vbsWin = string.gsub(vbs, "/", "\\")
	local okX = pcall(function() os.execute('wscript //B //Nologo "' .. vbsWin .. '"') end)
	return okX
end

pcall(EnableGlobals)

-- DURABLE breadcrumb (2026-07-17 outage fix): dvar traces die with the session, and a plain
-- Steam launch has no console_mp.log - the lost-quad post-mortem had NOTHING to say whether
-- this chunk ever ran or which mode it saw. One appended line per open survives everything.
local function FL(s)
	pcall(function()
		local t = 0
		pcall(function() t = os.time() end)
		local f = io.open("players/acc_lb_boot_log.txt", "a")
		f:write(tostring(t) .. " " .. s .. "\n")
		f:close()
	end)
end

if URL == "" then
	-- no backend baked in (local-only build): nothing to opt into, nothing to spawn. Leaving
	-- acc_lb_consent unset makes GSC treat this like a bridge-down client -> no prompt (clean).
	X('set acc_lb_boot_trace "no_url"')
	pcall(DisableGlobals)
	return "no_url"
end

-- Default = "check" (REPORT only, NEVER spawn). Every real caller sets an explicit mode
-- (check/set1/set0/spawn), and only the HOST's cmd dvar round-trips to its own client; a co-op peer
-- that can't read the dvar falls back to "check" -> it NEVER launches a helper. So ONLY the host can
-- ever get the console flash, in every scenario - a peer machine physically can't spawn one here.
local mode = readdvar("acc_lb_boot_cmd")
FL("open mode='" .. mode .. "'")   -- "" here while GSC set "spawn" = the dvar-read race, on record
if mode == "" then mode = "check" end

-- LIVENESS PROBE modes (the "quick retry, no cmd window" fix, docs/40). PURE IO, NO os.execute
-- => ZERO console flash. GSC (agent_is_alive) drives a two-step handshake that mirrors the
-- launcher pre-spawn (spawn_lb_agent.tpl.ps1): "ping" writes the trigger, "pongcheck" reads the
-- agent's reply. Because BlackOps3.exe - and the agent .bat - persist across map_restart within
-- one Steam app session, a prior match's agent answers, so every retry/restart REUSES it and the
-- spawn (the one os.execute) is skipped. Both branches early-return before ever reaching
-- spawn_agent, so they are the same flash-free class as "check"/"set0".
if mode == "ping" then
	-- delete any STALE pong first (a dead agent's leftover reply must not read as "alive"),
	-- then write the ping. A live agent's poll loop deletes it + writes pong within ~1s.
	pcall(function() os.remove("players/acc_lb_pong.txt") end)
	pcall(function()
		local f = io.open("players/acc_lb_ping.txt", "w")
		f:write("ping\n")
		f:close()
	end)
	FL("ping written")
	X('set acc_lb_boot_trace "pinged"')
	pcall(DisableGlobals)
	return "ping"
end

if mode == "pongcheck" then
	-- read the agent's pong reply; present => an agent is ALIVE in this app session. Consume it
	-- (os.remove) so a later probe can never read a stale pong.
	local alive = false
	pcall(function()
		local f = io.open("players/acc_lb_pong.txt", "r")
		if f ~= nil then
			local v = f:read("*a")
			f:close()
			if v ~= nil and string.find(v, "pong", 1, true) ~= nil then alive = true end
		end
	end)
	pcall(function() os.remove("players/acc_lb_pong.txt") end)
	FL("pongcheck " .. (alive and "alive" or "dead"))
	X('set acc_lb_boot_trace "' .. (alive and "alive" or "dead") .. '"')
	pcall(DisableGlobals)
	return (alive and "alive" or "dead")
end

if mode == "spawn" then
	local ok = spawn_agent()
	FL("spawn " .. (ok and "OK" or "FAIL"))
	X('set acc_lb_boot_trace "spawn' .. (ok and "1" or "0") .. '"')
	pcall(DisableGlobals)
	return "spawned"
end

if mode == "set1" then
	write_consent("1")
	local ok = spawn_agent()
	X('set acc_lb_consent "1"')
	X('set acc_lb_boot_trace "set1_' .. (ok and "1" or "0") .. '"')
	pcall(DisableGlobals)
	return "set1"
end

if mode == "set0" then
	-- decline is idempotent + non-destructive: NEVER overwrite an existing opt-in (a co-op
	-- peer can get re-prompted because its Exec doesn't reach the server; ignoring that
	-- re-prompt must not silently turn OFF a board it already enabled).
	local cur = read_consent()
	if cur ~= "1" then write_consent("0") end
	X('set acc_lb_consent "' .. (cur == "1" and "1" or "0") .. '"')
	X('set acc_lb_boot_trace "set0"')
	pcall(DisableGlobals)
	return "set0"
end

-- default "check": REPORT the saved choice to GSC and NEVER spawn here. Blackscreen spawning
-- is exactly the gameplay tab-out we removed; opted-in players spawn at end_game instead.
local c = read_consent()
X('set acc_lb_consent "' .. c .. '"')
X('set acc_lb_boot_trace "check_' .. c .. '"')
pcall(DisableGlobals)
return "check"
