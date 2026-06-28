# 24 — Test Session Guide (everything hardcoded ON)

> This build is a **dev test sandbox**: all the convenience features below are
> **hardcoded ON** (no dvars/flags needed). They're tagged `HARDCODED` in the
> source — re-gate them behind dvars before any Workshop ship.

## Launch

Double-click **`PLAY_TEST_MAP.bat`** (repo root), or run `.\tools\run_game.ps1`.

The one load-bearing arg is **`+set_gametype zclassic`** (already in both) — see
[docs/23_launch_runbook.md](23_launch_runbook.md) for why `g_gametype` doesn't work.

**If the game doesn't open** (Steam's launch handler can jam after force-quits):
fully restart Steam (`Steam → exit`, reopen), then launch again. A normal load
climbs to ~4.7 GB over ~40 s.

## What's hardcoded ON this build

| Feature | Behaviour |
|---|---|
| **Map fully open** | Every door is opened + every zone activated at spawn — walk the whole map immediately, no buying, never stuck in the start room. |
| **Unlimited money** | Points top back up to ~1,000,000 whenever they drop. |
| **Unlimited Data Shards** | Topped to the cap — for Cyberware / Overclocks. |
| **Power** | NOT auto-on — flip the Bus Station power switch yourself (perks/PaP/traps gate on it), same as normal play. |
| **Test boss** | A Juggernaut Host spawns ~10 s into **round 2** (and each round after), dropping **10 Mega Bottles** on death. |
| **Status banner** | First ~15 s: `[ACC] DEV BUILD LIVE - map open, power on, systems: COMPLETE`. `COMPLETE` confirms the full `_acc_` init chain ran. |
| **Zombie speed curve** | Zombies ramp 50% → 100% speed over rounds 1–10, then +1%/round. Live-tune: `set acc_zspeed_start_pct <n>` / `set acc_zspeed_max_round <n>` (read per spawn). |

## Test checklist

1. **Spawn** — confirm the green `[ACC] DEV BUILD LIVE … systems: COMPLETE` banner
   and points jumping to ~1,000,000. (If it says `pending` instead of `COMPLETE`,
   a module init failed — tell me.)
2. **Move freely** — walk out of the start room and through every zone (Market,
   Alley, Corp, Vault, Roof, Lab). Note any spot where geometry still blocks you.
3. **Perks (all 9)** — buy every perk machine; confirm each effect (power is on).
4. **Guns** — buy the wall weapons; spam the **Mystery Box**; confirm they fire.
5. **Pack-a-Punch** — PaP a gun (start room, power on); confirm T1 damage, T2 `_up` transform, T3 max.
6. **Boss + Mega Bottles** — reach round 2, kill the Juggernaut Host, confirm
   **10 bottles** (counter, bottom-left).
7. **Perk upgrades** — with bottles, at a perk machine you own, the "Hold ✋ for
   Mega upgrade" prompt appears → upgrade. Test several (Jug→Ultimate Tank,
   Stamin-Up→The Flash, Deadshot→American Sniper, …).
8. **Data Shards / Cyberware / Overclocks** — shards are maxed; find the kiosk(s)
   and confirm you can buy Cyberware nodes / roll Overclocks.
9. **Zombie speed curve** — early rounds shamble; speed climbs each round, reaching full sprint at round 10 and inching past it after. Optionally tune `acc_zspeed_start_pct` and re-check the feel.

## Reporting back

For anything broken, note: **which system**, **what you did**, **what happened**
(or didn't). Examples: "Speed Cola upgrade did nothing", "box gave a non-zm gun",
"can't reach the Lab — wall at X", "shards HUD not showing". When you quit, the
console log (`<game>\console_mp.log`) captures `[acc]` breadcrumbs + any runtime
error for me to cross-check.
