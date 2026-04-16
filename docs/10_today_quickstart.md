# 10 - Today Quickstart

**Goal**: ship the smallest possible thing - one box room, starting pistol (stock), one zombie barrier - to Steam Workshop (Private visibility) **today**.

This is a throwaway test. It's not the real map. The point is to prove end-to-end: Mod Tools installed, you can build, you can publish.

## Hard Reality Check (Read First)

The **BO3 Mod Tools are Windows-only**. This repo is on macOS. Before anything else, answer:

**Do you have access to a Windows PC that can run BO3?**

- **Yes, already set up**: skip to Step 3.
- **Yes, but nothing installed yet**: expect Steps 1-2 to take 1-3 hours just on downloads.
- **No, I'm Mac-only**: you will not ship today. You need to either:
  - Install Windows via Boot Camp (Intel Macs only - doesn't work on Apple Silicon).
  - Run Windows in a VM via Parallels (~$100/yr) - slow, but works for Mod Tools. BO3 itself in a VM is a gamble.
  - Get access to a Windows machine (borrow, cloud PC like Shadow/Paperspace, build a tower).
  - **Realistic plan if Mac-only**: today = order/set up the Windows option. "Ship it" target slips by however long that takes.

Everything below assumes you're on a Windows box with a working internet connection and a Steam account that owns BO3.

## Time Budget

If everything goes right and downloads are cached: **3-5 hours**. First-time, from-scratch: **5-8 hours** due to download/install sizes.

## Step-by-Step

### Step 1 - Install the Mod Tools (~60-90 min, mostly downloading)

1. Open Steam. Make sure you own **Call of Duty: Black Ops III**.
2. In your Steam library, filter the left sidebar to **Tools**.
3. Find **Call of Duty: Black Ops III - Mod Tools**. Install it. Expect ~60 GB download.
4. First launch: it runs a **one-time extraction** of stock assets. This is slow (30-60 min). Let it finish.
5. When it's done, the **Launcher** window is what you see. That's your home base.

**Verify**: the Launcher opens without errors and shows a map list.

### Step 2 - Install Supporting Tools (~15 min)

1. **VS Code** (free, from code.visualstudio.com). We'll use this for any GSC editing.
2. Optional - a GSC syntax extension for VS Code. Search the marketplace for "GSC" or "Call of Duty GSC". Not required for today.

### Step 3 - Create a New Map from the zm Template (~10 min)

1. In the Launcher, click **New Map** (or **File -> New Map**, UI varies).
2. Choose template: **zm** (zombies).
3. Name it: `zm_acc_test` (acc = abandoned cyber city, test = throwaway). Using a distinct name keeps our real future map `zm_abandoned_cyber_city` clean.
4. The Launcher generates a folder tree in `<steam>\steamapps\common\Call of Duty Black Ops III\usermaps\zm_acc_test\`.

**Verify**: `usermaps\zm_acc_test\` exists and contains `maps/`, `scripts/`, `zone_source/` subfolders.

### Step 4 - Open the Map in Radiant (~5 min)

1. Back in Launcher, select `zm_acc_test` from the map list.
2. Click **Launch Radiant** (or the Radiant button in the toolbar).
3. Radiant opens with your map loaded. The zm template already includes:
   - A starting room with a player spawn.
   - One barrier (boarded window) with a zombie spawn behind it.
   - A perk machine slot.
   - A Mystery Box spawn.
   - Round manager hooks.

**This is already your "box room with pistol and barrier".** The zm template ships with exactly what you asked for. You don't need to model anything.

Players start with a stock pistol (M1911) by default. The barrier spawns one zombie. Done.

### Step 5 - Optional Tiny Customization (~10 min, skip if nervous)

If you want to put your mark on it, just change one thing. Pick one:

- Move the player spawn with **T** in 2D view and click-drag.
- Scale the room brush to be bigger: select the room wall brushes and drag faces.
- Place a second zombie barrier: select the existing barrier prefab (pattern in 2D view), **Ctrl+C / Ctrl+V**, move to another wall.

Do **not** do more. Every change is a new thing that can break. Today is about shipping, not building.

**Save** the map: **File -> Save** in Radiant.

### Step 6 - Build the Fast File (~3-10 min)

1. Back in Launcher, with `zm_acc_test` selected:
2. Click **Compile Map** (or **Build Fast File**). The build log scrolls. Watch for errors.
3. Expect first build to take 5-10 min. Subsequent builds are faster.

**Verify**: log ends with `build successful` (or equivalent). An output `.ff` file now exists in `zone_out\`.

**If build fails**: most common cause is a missing asset. Copy the error line, search UGX Mods wiki or ask in a modding Discord. Don't panic - first-build errors are common and almost always already documented somewhere.

### Step 7 - Run the Map Locally (~5 min, first real payoff)

1. In Launcher, click **Run Game** / **Play** / **Test Map**.
2. BO3 launches into your map as a zombies game.
3. You walk around a box room. You have a pistol. Zombies spawn at the barrier. **That's the whole thing.**

**Verify**: you can play round 1 without crashes.

### Step 8 - Publish to Steam Workshop (Private) (~10 min)

1. In Launcher: **File -> Publish Mod/Map** (exact menu label may differ).
2. Fill in:
   - **Title**: "zm_acc_test - dev build". Explicitly mark it as a test so anyone who stumbles across it knows.
   - **Description**: "Throwaway test map for Abandoned Cyber City project. Not for public play."
   - **Tags**: Zombies, Custom Map.
   - **Thumbnail**: any 512x512 PNG. Placeholder is fine - take a screenshot in Radiant, crop it.
   - **Visibility**: **Private (Hidden)**. Critical. We don't want this on the public Workshop.
3. Click **Upload**. Wait for progress bar. A Workshop URL is printed in the log / dialog.

**Verify**: you can open the Workshop URL in your browser and see the item.

### Step 9 - Subscribe and Verify End to End (~5 min)

1. On the Workshop page, click **Subscribe**.
2. Launch BO3 normally (not through Launcher).
3. Go to Zombies -> Custom Maps (or wherever custom zombies maps are listed in-game).
4. Your map should appear. Load it. Play it.

**This is the ship test.** If another Steam account with the Workshop URL can subscribe and play it, you're done.

## Done Criteria for Today

- Mod Tools installed and compiling.
- A zm-template box-room map builds and runs locally.
- The map is published to Steam Workshop (Private).
- You can subscribe to it from Steam and play it in-game.

If all four are true: you've shipped. Close the laptop. Tomorrow starts Phase 1/2 proper.

## Known "Today" Gotchas

- **The first asset extraction is slow.** Don't interrupt it. Starting cleanly the second time is worse than waiting.
- **"Launcher doesn't see my Steam session"**: ensure the Steam client is running and logged in *before* you open Launcher.
- **"Map doesn't appear in BO3 after subscribing"**: unsubscribe, restart Steam, re-subscribe. This is a Steam sync quirk.
- **Antivirus flags the Mod Tools**: some AVs flag Radiant / APE because of how they write to disk. Whitelist the install directory.
- **Windows display scaling breaks Radiant**: if Radiant UI is tiny or huge, right-click `radiant_modtools.exe`, Properties -> Compatibility -> Change high-DPI settings -> Override high DPI scaling (Application).

## After Today

You will have proven:
- Your machine can build and ship a BO3 custom map.
- Steam Workshop publishing works for you.
- You understand the iterate loop (edit -> compile -> run -> publish).

That unblocks the real work in `08_milestones.md` Phase 2 onward. The `zm_acc_test` Workshop item stays as a sandbox - we'll keep throwing builds at it to test new GSC scripts before merging them into the real `zm_abandoned_cyber_city` map.

## If "Today" Slips (honest expectations)

It's more likely than not that **today you install and extract the Mod Tools**, and **tomorrow you do Steps 3-9**. The initial extract is long enough that if you're starting at 8pm, you're going to bed during Step 1. That's fine. This is still the fastest meaningful-progress day possible.
