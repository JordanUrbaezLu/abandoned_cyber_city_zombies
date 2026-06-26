# 55 — Release Runbook (Steam Workshop)

The single, authoritative procedure for getting **Abandoned Cyber City** onto the
Steam Workshop. It supersedes the publish bits scattered across
[09_language_and_publishing.md](09_language_and_publishing.md) (background/theory)
and [18_first_build_checklist.md §Step 5–6](18_first_build_checklist.md) (the
original first-publish notes). When in doubt, follow this doc.

> **One script drives the readiness gate:** `tools/prep_release.ps1`. It runs the
> asset gate → build → and every release check below, then prints a two-track
> verdict. It **never uploads** — the Steam publish is a manual Launcher click tied
> to your Steam session (by design; see "What the script will not do").

---

## The two tracks

| | **Track A — Private dev/test publish** | **Track B — Public v1.0 release** |
|---|---|---|
| Purpose | Hidden Workshop item for playtesting (share the URL with friends) | The real, world-visible release |
| Visibility | **Private / Hidden** | **Public** |
| Gate | A clean build + sane metadata | Track A **plus** the IP/credit review, polished metadata, screenshots, and a content/balance pass |
| Who can do it now | Ready today (we have a fresh `.ff`) | Blocked on the IP sign-off (mostly async author permission) + presentation assets |

**Do Track A first.** A Public release that hasn't passed Track A has never been
proven to build, load, and play from a real Workshop subscription.

---

## Current state (verified 2026-06-24)

- Mod Tools **are** installed on this box; the pipeline builds. (If you ever read
  "Mod Tools not installed" in `MISSING_REQUIREMENTS.md §1`, that section is stale —
  ground truth is `bin\modlauncher.exe` present + a fresh packed `.ff` on disk.)
- A valid `.ff` (~37 MB) exists at
  `…\usermaps\zm_abandoned_cyber_city\zone\zm_abandoned_cyber_city.ff`.
  **Build output lives in `usermaps\<map>\zone\`, not `zone_out\`.**
- `zone/workshop.json` (release-ready template, empty `PublisherID`) and
  `zone/previewimage.png` are committed. `CREDITS.md` carries the IP sign-off gate.
- ✅ **LED bake passes** (verified 2026-06-24, ~15s); the latest `.ff` has fresh
  lightmaps. Note: the LED bake can occasionally crash *transiently* with exit
  `-1073741819` (0xC0000005) on the first run of a session — that mimics the
  `brush.cpp:1860` gate but usually **just re-running the build bakes clean**
  (confirmed: HEAD + the working `.map` both baked 3/3 in isolation via
  `tools/_bake_test.ps1`). `prep_release.ps1` gates on `.led` being newer than
  `.d3dbsp`, so a transient crash can't silently ship stale lightmaps — if it FAILs,
  rebuild; if it *still* fails (a true hang that won't bake on retry), then it's real
  geometry — see memory `led-relight-dead-end-enclosed-geometry` and
  [40_lighting_blocker_report.md](40_lighting_blocker_report.md).

---

## TRACK A — Private dev/test publish

### A1–A4. Gate + build (one command)

```powershell
cd c:\Users\Jordan Urbaez\Repositories\abandoned_cyber_city_zombies
.\tools\prep_release.ps1            # asset gate -> FULL build (LED bake) -> all checks -> verdict
```

- **Close BO3 first** (building while the game runs corrupts the zone → a 0.00 MB `.ff`).
- It does **not** pass `-SkipLED` — the LED bake is the gate and currently passes.
- Want only the readiness report (no ~15-min rebuild, reuse the existing `.ff`)?
  `\.\tools\prep_release.ps1 -NoBuild`.
- Re-deploy the perk-icon GDT too (only needed if it changed): add `-DeployPerkShaders`.

**Success oracle:** the verdict prints `TRACK A … READY` and exit code is 0. (Build
success = a *fresh, >1 MB* `.ff`, never the linker exit code — it prints waived
`ERROR:` lines for substituted materials and still packs a valid file.)

### A5. Publish in the Launcher (manual — your action)

1. Start Steam, log in fully. Close BO3.
2. Open **Launcher** (Steam → Library → Tools → BO3 Mod Tools). `zm_abandoned_cyber_city`
   appears in the map list (the build's sync created it). If not: Launcher
   **New Map → zm → zm_abandoned_cyber_city**, then re-run the build (the sync
   overwrites the generated files — correct and intended).
3. Select the map → **File → Publish Mod/Map**.
4. Fields (pre-filled from `zone/workshop.json`): Title, Description,
   **Tags = `Map,Zombies`**, **Type = `map`**, Thumbnail → `zone\previewimage.png`.
   > ⚠️ The `Thumbnail` field MUST be an **absolute path** to `previewimage.png` (the
   > committed `workshop.json` already is). A *relative* path (`zone/previewimage.png`) makes
   > the Launcher fail with **"Error updating Steam Workshop item"** —
   > `Steam\logs\workshop_log.txt` shows `Failed to read preview file` even though the item is
   > created and the map content uploads fine. See §Gotchas.
5. **Visibility = Private / Hidden.** ← critical; this build is unreleasable IP until Track B.
6. **Upload.** Save the Workshop URL.

### A6. Capture the PublisherID back into the repo

```powershell
.\tools\sync_to_modtools.ps1 -Reverse     # pulls the Launcher-written workshop.json (now with PublisherID) into zone/
git add zone\workshop.json
git commit -m "chore: capture Workshop PublisherID"
```

This is what makes every **future** publish *update the same item* instead of
creating duplicates. Do it once, right after the first upload.

### A7. Subscribe-and-play verification

Open the URL → **Subscribe** → launch BO3 normally (`PLAY_TEST_MAP.bat`, **not** the
Launcher Run checkbox) → Zombies → Custom Games → load and survive a round. That's the
end-to-end proof: repo → build → publish → subscribe → play.

### A8. Playing co-op with friends (off the Workshop item)

The published `.ff` ships with **dev mode OFF** (the launch scripts pass the dev flags
locally; subscribers get the clean consumer game — closed map, earn your own money, decon
hazard live). Co-op scaling is built in (`_acc_coop_scaling.gsc`, [15_coop_rules.md](15_coop_rules.md)).

1. **Visibility for friends:** set the item to **Friends-Only** (friends see it in their
   Workshop with no link) *or* **Unlisted** (anyone with the direct URL can view/subscribe;
   not in search). Both are fine before the IP review — only *fully Public* needs the sign-off.
   > ⚠️ **NOT "Private"** (a.k.a. Hidden) — on Steam that means **author-only**, so a friend's
   > direct link FAILS even though the item exists. (Hit on the first publish, 2026-06-24: the
   > item was Private, the friend's URL 404'd.) Change it on the item's Steam page → right-side
   > **Visibility** dropdown (instant, no re-publish). If others still can't see a fresh item,
   > accept the Steam Workshop Legal Agreement once:
   > https://steamcommunity.com/sharedfiles/workshoplegalagreement
2. **Everyone subscribes** to the same Workshop item (Steam auto-delivers the same version,
   so no host/client `.ff` mismatch). Let it finish downloading before launching.
3. **Host:** launch BO3 (normally, through Steam) → **Zombies** → pick *Abandoned Cyber
   City* from the subscribed maps → set the lobby to **Online** (not Solo/LAN).
4. **Invite:** Steam overlay (Shift+Tab) → right-click the friend → **Invite to Game**, or
   use the in-game Friends list. Friend accepts → joins the lobby → host starts the match.
5. **Caveats:** BO3 co-op is peer-to-peer, so the host needs decent connectivity; all
   players must have the map fully downloaded and on the same version before joining.

---

## TRACK B — Public v1.0 release

Everything in Track A, **plus** the gates below. `tools/prep_release.ps1 -Public`
turns these from warnings into hard failures, so you can use it as the final gate.

### B1. 🔴 IP / licensing sign-off — the hard gate

The shipped `.ff` bundles **game-rip community packs with no inherent redistribution
licence**. [CLAUDE.md](../CLAUDE.md) forbids a Public flip until this is resolved.
The checklist lives in **[CREDITS.md → "IP review sign-off"](../CREDITS.md)** and is
machine-checked via the marker line `IP REVIEW STATUS: INCOMPLETE`.

For each asset, **either** confirm the author permits bundling in a free Workshop map
**or** remove the asset from the build:

| Asset | Author(s) | Original IP |
|---|---|---|
| Charred Zombie reskin | Logical (+ Scobalula tools) | Treyarch DLC3/4 |
| Ronan perk-icon shaders | Ronan | Treyarch + Anna Kuźmińska + CD Projekt Red |
| Action Figure melee | T0nic | Treyarch (BO4) |
| NSZ Brutus mini-boss | NateSmithZombies | Treyarch (BO2) |
| Skye weapon ports | TheSkyeLord + LilRobot | Treyarch / Sledgehammer (BO2/BO3/AW) |
| L3akMod (build tool) | D3V Team | — (credit required by its licence) |
| `acc_main_theme` audio | StockTune "Ethereal Neon Odyssey" | ⚠️ **not confirmed CC0** — verify it permits Workshop redistribution, or swap to a confirmed-CC0 track |

When every box in CREDITS.md is checked and every author is credited in the Workshop
description, **flip the marker to `IP REVIEW STATUS: COMPLETE`**. `prep_release.ps1`
then passes the IP gate.

Ship policy ([29_atmosphere_and_materials.md §8](29_atmosphere_and_materials.md)):
**stock BO3 / original / CC0 only.** Anything else needs explicit permission or removal.

### B2. Workshop description + credits block

Rewrite `zone/workshop.json`'s Title/Description for a real audience (the prep script
flags any leftover "dev build / not for public" text). Include the full credits block,
e.g.:

```
[b]Credits[/b]
Map & systems: <your handle>
Custom LUI compiled with L3akMod — D3V Team
Charred zombie skin: Logical (rip tools by Scobalula) — © Treyarch (DLC3/4)
Perk HUD icons: Ronan "Cyberpunk Shaders" — Ronan, Treyarch, Anna Kuźmińska, CD Projekt Red
Action Figure melee: T0nic — © Treyarch (BO4)
Brutus mini-boss: NateSmithZombies — © Treyarch (BO2)
Weapon ports: TheSkyeLord + LilRobot — © Treyarch / Sledgehammer
Music: <StockTune track, or your CC0 replacement>
```

### B3. Presentation assets

- **Thumbnail:** replace `zone/previewimage.png` with a **512×512** hero image
  (current placeholder is 600×340 — the script warns).
- **Screenshots:** capture **5–10** at 1920×1080 (Plaza, weapons, perks, a boss, the
  underground vault, a round-10+ moment). Save as `zone/screenshot_NN_*.png` (or in
  `zone/screenshots/`) so the prep script counts them; add them to the Workshop page in
  the Launcher dialog / via Steam's image manager.

### B4. Content + balance check (decision, not a blocker)

~202/471 requirements are implemented ([20_requirements_checklist.md](20_requirements_checklist.md)),
greybox-with-stock-art. That can ship as a legitimate "systems-depth greybox" v1.0 if
marketed honestly — decide consciously. Imported guns
([21_weapon_import_sources.md](21_weapon_import_sources.md)) and the Phase-4 LUI/HUD
are the main open buckets. Do a solo + co-op balance pass to round 30+ first.

### B5. Flip to Public

```powershell
.\tools\prep_release.ps1 -Public     # final gate: every Track-B blocker is now FATAL
git tag v1.0.0                        # tag the release; add a CHANGELOG v1.0.0 entry
```

Then repeat the Launcher publish (A5) with **Visibility = Public** and the finalized
metadata. Announce on the modding forums (UGX / Modme / r/CODZombies) with a changelog.

---

## What `prep_release.ps1` will NOT do (by design)

- **Never uploads / publishes.** The Steam upload requires your logged-in Steam
  session and is outward-facing + hard to fully undo — so it stays a deliberate manual
  Launcher click.
- **Never flips visibility.** Private vs Public is the Launcher dialog's call.
- **Never edits game code, geometry, GDT, or assets.** It calls the *same* build
  pipeline you already run (`build_map.ps1`) and otherwise only reads files.

---

## Gotchas (carried from the build/launch runbooks)

- **Build output is in `usermaps\<map>\zone\`**, not `zone_out\`.
- **Build success = a fresh, >1 MB `.ff`**, never the linker's exit code.
- **Never build while BO3 is running** → zone corruption (0.00 MB `.ff`); close it first.
- **The linker compiles the *deployed* usermap copy** — the build syncs first, so don't
  hand-edit `usermaps\`.
- **Re-publishing updates the same item only if `zone/workshop.json` has the
  PublisherID** — hence the A6 `-Reverse` + commit. (First publish 2026-06-24 captured
  `PublisherID 3751124295`.)
- **`Thumbnail` MUST be an absolute path** to `previewimage.png`. The Launcher resolves it
  relative to its *own* working dir (not the usermap folder), so a relative
  `zone/previewimage.png` fails with **"Error updating Steam Workshop item. Error code:"** —
  the real cause is in `Steam\logs\workshop_log.txt`: `[AppID 455130] Failed to read preview
  file zone/previewimage.png`. By then the item is already **created** and the map content
  (`.ff`+`.xpak`) is **already uploaded** — only the preview upload failed; just fix the path
  and re-publish (it updates the same item). The committed `workshop.json` now uses an absolute
  path (dev-box-specific, fine for this single-box repo). Hit + fixed on the first publish,
  2026-06-24.
- **Steam Launch Options must be EMPTY** and launch uses `+set_gametype zclassic`
  (handled by `PLAY_TEST_MAP.bat`) — see [23_launch_runbook.md](23_launch_runbook.md).
