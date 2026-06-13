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
| **Auto-power** | Power is ON at spawn (perks, Pack-a-Punch, traps all work immediately). |
| **Test boss** | A Juggernaut Host spawns ~10 s into **round 2** (and each round after), dropping **10 Mega Bottles** on death. |
| **Status banner** | First ~15 s: `[ACC] DEV BUILD LIVE - map open, power on, systems: COMPLETE`. `COMPLETE` confirms the full `_acc_` init chain ran. |
| **Rampage Inducer** | Console (`~`): `set acc_rampage 1` → zombies sprint + spawn faster; `set acc_rampage 0` off. |

## Test checklist

1. **Spawn** — confirm the green `[ACC] DEV BUILD LIVE … systems: COMPLETE` banner
   and points jumping to ~1,000,000. (If it says `pending` instead of `COMPLETE`,
   a module init failed — tell me.)
2. **Move freely** — walk out of the start room and through every zone (Market,
   Alley, Corp, Vault, Roof, Lab). Note any spot where geometry still blocks you.
3. **Perks (all 9)** — buy every perk machine; confirm each effect (power is on).
4. **Guns** — buy the wall weapons; spam the **Mystery Box**; confirm they fire.
5. **Pack-a-Punch** — PaP a gun (start room, power on); confirm upgrade + camo.
6. **Boss + Mega Bottles** — reach round 2, kill the Juggernaut Host, confirm
   **10 bottles** (counter, bottom-left).
7. **Perk upgrades** — with bottles, at a perk machine you own, the "Hold ✋ for
   Mega upgrade" prompt appears → upgrade. Test several (Jug→Ultimate Tank,
   Stamin-Up→The Flash, Deadshot→American Sniper, …).
8. **Data Shards / Cyberware / Overclocks** — shards are maxed; find the kiosk(s)
   and confirm you can buy Cyberware nodes / roll Overclocks.
9. **Rampage Inducer** — `set acc_rampage 1` / `0`; confirm sprint + spawn changes.

## Reporting back

For anything broken, note: **which system**, **what you did**, **what happened**
(or didn't). Examples: "Speed Cola upgrade did nothing", "box gave a non-zm gun",
"can't reach the Lab — wall at X", "shards HUD not showing". When you quit, the
console log (`<game>\console_mp.log`) captures `[acc]` breadcrumbs + any runtime
error for me to cross-check.
