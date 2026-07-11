# 34 — Release Runbook (Steam Workshop)

The single, authoritative procedure for getting **Abandoned Cyber City** onto the
Steam Workshop. It supersedes the publish bits scattered across
[34_release_runbook.md](34_release_runbook.md) (background/theory,
now folded in below) and
[34_release_runbook.md §Step 5–6](34_release_runbook.md) (the original
first-publish notes). When in doubt, follow this doc.

> **One script drives the readiness gate:** `tools/prep_release.ps1`. It runs the
> ship-safe-flags gate → asset gate → build → LED-bake check → metadata/presentation/IP
> checks, then prints a two-track verdict. It **never uploads** — the Steam publish is a
> manual Launcher click tied to your Steam session (by design; see "What the script will not do").

---

## Simple version (no jargon)

If you just want the map online for friends, this is all you do. The detailed version
is the rest of this doc; you don't need it.

**The one thing that clears up the confusion:** a "script" is just a build command, and
**you never run scripts — Claude runs all of them for you.** There's **no website** to
visit; the upload happens inside a program called the **Launcher** (it ships with the BO3
Mod Tools). **Your only two jobs: (1) click _Upload_ in the Launcher, and (2) play.**

1. **Ask Claude to build it.** Type: *"Build the release."* Claude runs the whole
   pipeline (~15 min) and tells you when the map file is ready. (It may already be built.)
2. **Open the Launcher.** Steam → **Library** → search *mod tools* → *Call of Duty:
   Black Ops III - Mod Tools* → **Play** → click **Launcher**. First: **close the actual
   game (Black Ops 3)** if it's open.
3. **Upload the map.** In the Launcher: click **`zm_abandoned_cyber_city`** in the map
   list → **Publish** (a button, or **File → Publish Mod/Map**). The form is mostly
   pre-filled — just confirm **Title** `Abandoned Cyber City`, **Tags** `Map, Zombies`,
   the **Thumbnail** (`zone\previewimage.png`), and set **Visibility = Friends Only**
   (do **not** pick *Public* yet). Click **Upload**, wait ~a minute, and **copy the link
   it gives you.**
4. **Tell Claude you uploaded it.** Type: *"I published it."* Claude runs one tiny
   save-step so the next upload updates the *same* map instead of making a duplicate.
5. **Play it yourself.** Open the link in Steam → **Subscribe** (downloads the map) →
   start BO3 the normal way → **Zombies** → **Abandoned Cyber City** → play a round.
6. **Play with friends.** Send them the link (Friends-Only means they can also find it in
   their own Workshop). They **Subscribe** and wait for the download. You (host): BO3 →
   **Zombies** → pick the map → set the lobby **Online** (not Solo). Invite via **Shift+Tab**
   (Steam overlay) → right-click friend → **Invite to Game**.

**Tips:** both players must have the map fully downloaded first; you automatically get the
same version (no "mismatch"); friends can't join your local *test* launches — co-op only
works through the **subscribed Workshop map** + a Steam invite.

---

## The two tracks

| | **Track A — Private dev/test publish** | **Track B — Public v1.0 release** |
|---|---|---|
| Purpose | Hidden/Friends-Only Workshop item for playtesting | The real, world-visible release |
| Visibility | **Friends-Only / Unlisted** | **Public** |
| Gate | A clean build + sane metadata + the dev/god flags OFF | Track A **plus** the IP/credit review, the test-only music swap, real screenshots, and a content/balance pass |
| Who can do it now | One flip away — the only open blocker is the dev/god test hardcode in `acc_resolve_dev_flags()`; comment it out (below) and you're ready | Blocked on the IP sign-off (mostly async author permission), three test-only music tracks that must be swapped, and screenshots |

**Do Track A first.** A Public release that hasn't passed Track A has never been
proven to build, load, and play from a real Workshop subscription.

---

## Current state (reconciled 2026-07-10)

- Mod Tools **are** installed on this box; the pipeline builds. (If you ever read
  "Mod Tools not installed" in `MISSING_REQUIREMENTS.md §1`, that section is stale —
  ground truth is `bin\modlauncher.exe` present + a fresh packed `.ff` on disk.)
- The map is **fully built** (first clean compile 2026-06-12; ~48 active `_acc_` modules
  orchestrated in `_acc_main.gsc::init()`, plus the bosses threaded from the entry script).
  A valid, fresh `.ff` (tens of MB — it grew a lot as the asset packs landed) lives at
  `…\usermaps\zm_abandoned_cyber_city\zone\zm_abandoned_cyber_city.ff`.
  **Build output lives in `usermaps\<map>\zone\`, not `zone_out\`.**
- `zone/workshop.json` is **fully filled in and committed** — Title
  `Abandoned Cyber City [SUPER HARD]`, `Tags = Map,Zombies`, `Type = map`, an absolute
  `Thumbnail` path, a written BBCode Description, and **`PublisherID` 3751124295** already
  captured (so future publishes update the same item; see A6). `zone/previewimage.png` is
  **512×512** (the prep-script thumbnail gate passes). `CREDITS.md` carries the IP sign-off gate.
- ⚠️ **The dev/god flags are currently HARDCODED ON.** `acc_resolve_dev_flags()` in
  `scripts/zm/zm_abandoned_cyber_city.gsc` has active `level.acc_dev = true;` (~line 376)
  and `level.acc_god = true;` (~line 412) test lines sitting *below* the normal
  `getdvarint()` resolution. `prep_release.ps1` Gate 0 FAILs on these — **comment out both
  lines before any publish** (see A1). An invulnerable full-dev build must never ship.
- ✅ **LED bake passes.** After the pre-stage3 geometry revert the map bakes again
  (~157 light entities); `build_map.ps1` runs the LED bake **by default** and `-SkipLED`
  is a RED FLAG. The bake can occasionally crash *transiently* with exit `-1073741819`
  (0xC0000005) on the first run of a session — that mimics the `brush.cpp:1860` gate but
  usually **just re-running the build bakes clean**. `prep_release.ps1` gates on the `.led`
  being newer than the `.d3dbsp`, so a transient crash can't silently ship stale lightmaps —
  if it FAILs, rebuild; if it *still* fails (a true hang that won't bake on retry) it's real
  geometry — see memory `led-relight-dead-end-enclosed-geometry` and
  [BO3_MAPMAKING_KB.md](BO3_MAPMAKING_KB.md).

---

## TRACK A — Private dev/test publish

### A1–A4. Gate + build (one command)

```powershell
cd c:\Users\Jordan Urbaez\Repositories\abandoned_cyber_city_zombies
.\tools\prep_release.ps1            # ship-safe gate -> asset gate -> FULL build (LED bake) -> all checks -> verdict
```

- **Close BO3 first** (building while the game runs corrupts the zone → a 0.00 MB `.ff`).
- **Gate 0 "ship-safe flags" (added 2026-07-08):** FAILS Track A if the entry script still
  carries an active `level.acc_dev = true;` **or** `level.acc_god = true;` test hardcode in
  `acc_resolve_dev_flags()` (an invulnerable full-dev build must never publish — even
  Private). **Comment out / delete both hardcode lines** in
  `scripts/zm/zm_abandoned_cyber_city.gsc` so the flags fall back to their `getdvarint(…, 0)`
  resolution (ship-safe default 0) before a publish run. As of 2026-07-10 both are ON.
- It does **not** pass `-SkipLED` — the LED bake is the gate and currently passes.
- Want only the readiness report (no ~15-min rebuild, reuse the existing `.ff`)?
  `.\tools\prep_release.ps1 -NoBuild`.
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
5. **Visibility = Friends-Only or Unlisted** for Track A. ← critical; this build is
   unreleasable IP until Track B. (See A8 for why **not** "Private/Hidden".)
6. **Upload.** Save the Workshop URL.

### A6. Capture the PublisherID back into the repo — ALREADY DONE

This step was completed on the first publish (2026-06-24 captured **PublisherID
3751124295**, committed in `zone/workshop.json`), which is what makes every **future**
publish *update the same item* instead of creating a duplicate. You do **not** need to
repeat it. Re-run it only if the Launcher ever writes a *new* `workshop.json` (e.g. a
fresh item):

```powershell
.\tools\sync_to_modtools.ps1 -Reverse     # pulls the Launcher-written workshop.json (with PublisherID) into zone/
git add zone\workshop.json
git commit -m "chore: capture Workshop PublisherID"
```

### A7. Subscribe-and-play verification

Open the URL → **Subscribe** → launch BO3 normally (`PLAY_TEST_MAP.bat`, **not** the
Launcher Run checkbox) → Zombies → Custom Games → load and survive a round. That's the
end-to-end proof: repo → build → publish → subscribe → play.

### A8. Playing co-op with friends (off the Workshop item)

The published `.ff` ships with **dev mode OFF** (once you've flipped Gate 0 — the launch
scripts pass the dev flags only *locally*, so subscribers get the clean consumer game:
closed map, earn your own money, decon hazard live). Co-op scaling is built in
(`_acc_coop_scaling.gsc`, [12_coop_rules.md](12_coop_rules.md)).

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
   players must have the map fully downloaded and on the same version before joining. Don't
   try to have a friend join a *local* test launch on your PC — co-op only works through the
   subscribed Workshop map + a Steam invite.

---

## TRACK B — Public v1.0 release

Everything in Track A, **plus** the gates below. `tools/prep_release.ps1 -Public`
turns these from warnings into hard failures, so you can use it as the final gate.

### B1. 🔴 IP / licensing sign-off — the hard gate

The shipped `.ff` bundles a large roster of **game-rip community packs with no inherent
redistribution licence** (bosses, weapon ports, zombie/boss reskins, machine models, the
Aetherium HUD, audio). [CLAUDE.md](../CLAUDE.md) forbids a Public flip until this is resolved.

**[CREDITS.md → "IP review sign-off (the PUBLIC-release gate)"](../CREDITS.md) is the
single source of truth** — a per-asset checklist (~two dozen packs) plus the full
provenance ledger. `prep_release.ps1` machine-checks it two ways: the marker line
**`IP REVIEW STATUS: INCOMPLETE`** (currently INCOMPLETE) must read `COMPLETE`, and every
named author (`NateSmithZombies`, `TheSkyeLord`, `LilRobot`, `Logical`, `Ronan`, `T0nic`,
`D3V`, …) must appear in `CREDITS.md`. For each asset: **either** confirm the author permits
bundling in a free Workshop map **or** remove the asset from the build.

Two clearance items are sharper than the rest — call them out explicitly:

- **🚫 Three test-only audio tracks MUST be removed or swapped before Public** (copyrighted,
  not licensed for redistribution): `acc_ee_song_3` ("I Really Want to Stay at Your House",
  CD PROJEKT RED), `acc_paradise_music` ("115", Treyarch/Kevin Sherwood), and
  `acc_paradise_calm` (Mario "Stage Win", Nintendo). Several other tracks are Pixabay/Freesound
  and only need their license **verified** (see the ⚠️ rows in CREDITS.md).
- **Apex Legends weapons are cross-publisher IP** (Respawn/EA, not Activision/Treyarch) — a
  stricter review bar than the CoD-family rips.

When every box in CREDITS.md is checked and every author is credited in the Workshop
description, **flip the marker to `IP REVIEW STATUS: COMPLETE`**. `prep_release.ps1`
then passes the IP gate.

Ship policy ([20_atmosphere_and_materials.md §8](20_atmosphere_and_materials.md)):
**stock BO3 / original / CC0 only.** Anything else needs explicit permission or removal.

### B2. Workshop description + credits block

`zone/workshop.json`'s Title/Description are **already written** for a real audience (the
prep script only flags leftover "dev build / not for public" text, and there is none). Two
things still need doing before Public:

- **Add the full credits block** to the Description — assemble it from the per-asset rows in
  [CREDITS.md](../CREDITS.md) (every author + original studio). Skeleton:
  ```
  [b]Credits[/b]
  Map & systems: <your handle>
  Custom LUI compiled with L3akMod — D3V Team
  Aetherium HUD: Owen-C137 (+ Kingslayer Kyle, Shidouri, MadGaz) — © Treyarch
  Bosses / enemies: NateSmithZombies (Brutus), Dick_Nixon (Avogadro), HarryBo21 (Civil Protector), Spiki (Panzer) — © Treyarch
  Weapon ports: TheSkyeLord + LilRobot; Apex pack: zeroy + ElTitoPricus — © Respawn/EA & others
  Perk HUD icons: Ronan — Treyarch, Anna Kuźmińska, CD Projekt Red
  Music: <confirmed-CC0 replacements for the 🚫 test-only tracks>
  ```
- **Replace the 7 `[img]SCREENSHOT-N-…[/img]` placeholders** in the Description with real
  uploaded-screenshot references (or drop them) — they are placeholder tokens, not URLs.

### B3. Presentation assets

- **Thumbnail:** ✅ done — `zone/previewimage.png` is already **512×512** (the prep script's
  thumbnail gate passes). Only revisit if you want a nicer hero image.
- **Screenshots:** still needed. Capture **5–10** at 1920×1080 (Plaza, weapons, perks, a
  boss, the Abyss descent, a round-10+ moment). Save as `zone/screenshot_NN_*.png` (or in
  `zone/screenshots/`) so the prep script counts them; add them to the Workshop page in the
  Launcher dialog / via Steam's image manager.

### B4. Content + balance check (decision, not a blocker)

The map is a **fully-built systems-depth zombies map**, not a greybox — the Aetherium LUI
HUD (shipped 2026-07-03), the gun-badge chip row (2026-07-08), a large box-only arsenal
(Apex pack + Skye ports + elemental bows), the Abyss Descent (soul-box layers → Paradise),
Exo Suit, Armory, Reactor Surge, Glitch Altar, Jukebox, The Exchange, Data Shards,
Cyberware, Overclocks, 5-tier Pack-a-Punch, Mega perks, and the multi-boss roster
(Brutus, Glitch, Phantom, Avogadro, Panzer, Rogue/Civil Protector) are all in. It art-passes
mostly on stock + ripped assets (hence the B1 IP gate). What "v1.0" means is a conscious
call — the real pre-release work is a **solo + co-op balance pass to round 30+** and
sweeping the requirements tracker ([15_requirements_checklist.md](15_requirements_checklist.md))
for anything you consider ship-blocking.

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

## Publishing background & troubleshooting (folded from docs/34)

You don't need a separate Steam developer account, a fee, App IDs / Steamworks setup, or
anyone's approval — Workshop publishing is one Launcher click that uses your existing Steam
session. Prerequisites: own BO3 on Steam, Mod Tools installed, Steam running + logged in, a
working `.ff`, and a thumbnail (we have a 512×512 one). **Updating vs. new:** the *first*
publish creates the item; the *same* Publish flow on the same map (with the PublisherID in
`workshop.json`) overwrites it as a new version and subscribers auto-update. Steam doesn't
surface version tags to players, so we track semver in the Workshop description text + git tags.

What can go wrong (and the fix):

- **Launcher can't find the Steam session** → make sure Steam is running and logged in
  *before* opening the Launcher.
- **Upload fails mid-upload** → usually network flakiness; retry.
- **Item shows "broken" on subscribers** → a fastfile compile error slipped through; rebuild
  and republish. (Our build oracle is a fresh, >1 MB `.ff` — not the linker exit code.)
- **Subscribed but the map isn't in the Zombies menu** → zone-source registration issue;
  rebuild. Also let the download fully finish before launching.
- **Rejected for TOS** → rare; happens on obvious copyright (licensed music, etc.). This is
  exactly what the B1 IP gate + the 🚫 test-only-music swap protect against.

---

## Gotchas (carried from the build/launch runbooks)

- **Build output is in `usermaps\<map>\zone\`**, not `zone_out\`.
- **Build success = a fresh, >1 MB `.ff`**, never the linker's exit code.
- **Never build while BO3 is running** → zone corruption (0.00 MB `.ff`); close it first.
- **The linker compiles the *deployed* usermap copy** — the build syncs first, so don't
  hand-edit `usermaps\`.
- **Re-publishing updates the same item only if `zone/workshop.json` has the
  PublisherID** — already captured (`PublisherID 3751124295`, first publish 2026-06-24), so
  no action unless the Launcher ever writes a fresh item (then re-run A6's `-Reverse` + commit).
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
  (handled by `PLAY_TEST_MAP.bat`) — see [17_launch_runbook.md](17_launch_runbook.md).
