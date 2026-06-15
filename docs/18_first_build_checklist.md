# 18 - First Build Checklist (starting-room build → Steam Workshop)

The repo now ships a **complete starting-room build kit**. This checklist takes
it from a fresh sync to a playable, Workshop-published build. Expected time on
a machine that already has Mod Tools installed: **~1 hour**, most of it compile
and upload waits. (Mod Tools not installed yet? Do [SETUP_WINDOWS.md](../SETUP_WINDOWS.md)
sections 1-2 first.)

## What this build is

- The stock zm template starting room (byte-identical copy in
  `map_source/zm/zm_abandoned_cyber_city.map`): player spawns, one barrier,
  zombie spawner, `start_zone`, perk machine slots, PaP, Mystery Box, power
  switch. It is deliberately unmodified - it is the known-good geometry that
  every working custom map starts from.
- All 18 `_acc_` systems compiled in and initializing. Systems whose geometry
  doesn't exist yet (Lab perk machines, dual power switches, hack terminal...)
  log `[acc]` lines and idle. Early-round pacing, points/damage hooks, and
  modifiers are live because they don't need geometry.
- Round 1+ is playable: buy the barrier wall, shoot zombies, survive.

## Step 1 - Sync (5 min)

```powershell
cd C:\dev\abandoned_cyber_city_zombies   # wherever you cloned it
.\tools\sync_to_modtools.ps1 -DryRun     # sanity-check the plan
.\tools\sync_to_modtools.ps1
```

**Verify**:
- `<BO3>\usermaps\zm_abandoned_cyber_city\zone_source\zm_abandoned_cyber_city.zone` exists.
- `<BO3>\usermaps\zm_abandoned_cyber_city\scripts\zm\zm_abandoned_cyber_city.gsc` exists.
- `<BO3>\map_source\zm\zm_abandoned_cyber_city.map` exists.

## Step 2 - Launcher sees the map (2 min)

1. Start Steam, then open **Launcher** from Steam (Library → Tools → BO3 Mod Tools).
2. `zm_abandoned_cyber_city` should appear in the map list (Launcher scans `usermaps\`).

**If it doesn't appear**: use Launcher **New Map → zm → zm_abandoned_cyber_city**
to register it, then re-run the sync (the sync overwrites the generated files
with ours - that is correct and intended).

## Step 3 - Compile (5-15 min first time)

1. Select `zm_abandoned_cyber_city`, check **Compile** (map + scripts + link), click **Build**.
2. Watch the log. Success ends with the linked fast file in `zone_out\`.

### If the build fails, in order of likelihood:

| Error shape | Fix |
|---|---|
| GSC syntax/unresolved symbol in `_acc_*.gsc` | A stock API name drifted. Grep that file for `TODO(acc-verify)` - the suspect call is documented at the call site. Compare against `share\raw\scripts\zm\` and fix the name. |
| `Could not find script scripts/zm/zm_abandoned_cyber_city/_acc_...` | The linker dislikes the module subfolder (rare; most community maps use subfolders fine). Fallback: move all `_acc_*.gsc` from `scripts\zm\zm_abandoned_cyber_city\` up into `scripts\zm\`, update the 18 `scriptparsetree` paths in the `.zone`, and the `#using scripts\zm\zm_abandoned_cyber_city\_acc_X;` lines to `#using scripts\zm\_acc_X;` in all files. Mechanical, ~10 min. |
| Missing asset on a `.zone` line | Comment the line out with `//` and note it. |
| Sound zone error mentioning `user_aliases.csv` / `ambient_mod.csv` | Comment out the `sound,zm_abandoned_cyber_city` line in the `.zone` for the first build (re-add when sound work starts in Phase 5). |
| Radiant/BSP error on the `.map` | The map is the stock template plus a small hand-authored addition (one wall brush, one chalk patch mesh, five script_structs - see CHANGELOG "start-room gameplay set"). If the error points at brush 19/20 or entities 33-37, suspect that addition; otherwise the sync copy corrupted line endings - re-clone with `git config core.autocrlf false` and re-sync. |

After fixing, use **Compile Scripts** (30-90s) instead of the full build when
only `.gsc` changed.

## Step 4 - Run it (10 min)

1. Launcher → **Run Game**.
2. BO3 boots into the map. You should spawn in the template room with a pistol
   and 500 points.
3. Open the console (~) and look for `[acc]` lines: `pre_init done`,
   `init complete`. (Dev console must be enabled in the Launcher run options.)

**Playtest the loop**: survive round 1-2, buy the barricade debris, confirm
zombies path through the window, confirm points award on kills (40/hit-kill
profile is ours, not stock - see docs/06_mechanics.md).

**7-zone greybox walkthrough** (2026-06-12 layout — all corridors open, no
buyable doors yet; zones: Spawn ↔ Market/Alley ↔ Corp ↔ Vault/Roof ↔ Lab):

- Walk Spawn → west corridor → Market (Mystery Box, stall row), north →
  Corp (ICR-1 + Sheiva wallbuys, power switch east wall, fountain + S-curve),
  east → Vault (Frag wallbuy) / west → Roof (Drakon wallbuy, central
  obstacle), north from either → Lab (all 9 perk machines, PaP, Bowie).
- Confirm zombies spawn in whichever zone you stand in (zone volumes +
  risers per zone; spawn lists rebuild ~1s after you cross a corridor).
- **Mega Bottle loop test**: launch with `+set acc_test_boss 1` (or set the
  dvar in console) → a 1500 HP Juggernaut Host spawns ~10s into every round
  from round 2 (boss headshot rule = 3x). Kill it → every player gets +1
  Mega Bottle (gold counter, bottom left). Buy a perk in the Lab, then look
  at the same machine again — a second hint ("Mega upgrade [1 Bottle]")
  appears only while you own that perk + hold a bottle. Apply and verify:
  Jug → +100 max HP (survive ~2 extra hits); Stamin-Up → visibly faster;
  Deadshot → bigger headshot numbers (+1.4 bonus, +1.8 Mega); Widow's Wine → melee
  one-hits regular zombies; PhD Flopper → "Overcharge" Mega (declarative TODO).

**Original single-room notes** (superseded, kept for the first compile):

- **Perk machines (9 of 9)**: north wall row west→east: Quick Revive, Jug,
  Speed Cola, Double Tap, Stamin-Up, Mule Kick, **Deadshot**; south perimeter
  wall: **Widow's Wine**; west perimeter wall: **PhD Flopper** (shows as the
  stock `p7_zm_vending_nuke` vending model + the Ronan `exo_flopper` HUD icon -
  both known greybox placeholders). Deadshot, Widow's Wine, PhD Flopper are
  hand-authored (inline structs), the other six are template prefabs.
- **PhD Flopper ability test**: buy it (2,500), then **DIVE TO PRONE** (sprint →
  go prone mid-air) near a group of zombies - expect a nova explosion that clears
  nearby zombies. You also take no fall or self-explosive damage, and explode when
  you go down. (Dive-triggered + passive immunity; no manual activation chord.)
- **Wallbuys (6)**: extended north wall: **ICR-1** (chalk) and **Haymaker 12**
  (no chalk - walk the wall for the hint prompt); south perimeter wall
  west→east: **Bowie Knife**, **Drakon** (sniper-slot stand-in for the
  Intervention import), **Sheiva** (semi-auto-AR-slot stand-in for the M14 EBR
  import), **Frag Grenade** (tactical-slot stand-in for the custom EMP
  grenade) - all four with chalk. Buy everything; expect stock CSV prices.
  Known TODO(acc-geom): Haymaker and Drakon display the ICR-1 world model
  after purchase (their real model names are unverified until the APE check;
  Bowie/Sheiva/Frag use verified models from shipped sources).
- **Mystery Box**: NW corner against the wall (template `box_start`). Hit it a
  few times - weapons spawn, box never flies away (single-chest map). The
  box-only roster guns that exist in stock (Brecci, XR-2, Locus, Drakon) come
  through the stock box pool; curation to our roster is a Phase 3 script pass.
- **Perimeter**: the whole template floor slab is now walled in (~2150x2000
  arena). Confirm you can't walk off the slab edge anywhere.

**Known first-run behaviors** (fine, not bugs):
- Early rounds are faster/denser than stock - that's `_acc_early_round_pacing`.
- `[acc]` warnings about missing `acc_*` targetnames - geometry that arrives in Phase 2.

**If the game crashes at load with a script runtime error**: the error names a
file:line. Almost always a `TODO(acc-verify)` API call. Comment out the call
site (or the whole offending module's line in `acc_main::init()` plus its
`scriptparsetree` line), rebuild scripts, rerun, file an issue note in
CHANGELOG. The module set is designed to degrade one-by-one.

## Step 5 - Publish to Workshop, Private (15 min)

1. In Launcher with the map selected: the publish panel (or **File → Publish**).
2. First publish: Launcher creates `usermaps\zm_abandoned_cyber_city\zone\workshop.json`.
   Copy field values from our `zone\workshop.json.example` (title, description,
   `Tags: Map,Zombies`, `Type: map`). Launcher fills `PublisherID` itself.
3. Thumbnail: point it at `zone\previewimage.png` (stock placeholder, fine for dev).
4. **Visibility: Private/Hidden.** This is a dev build.
5. Upload. Save the Workshop URL.
6. After Launcher finishes, run `.\tools\sync_to_modtools.ps1 -Reverse` so the
   generated `workshop.json` (with your PublisherID) flows back into the repo's
   `zone\` folder. Commit it - future publishes update the same Workshop item.

## Step 6 - Subscribe-and-play verification (10 min)

1. Open the Workshop URL, **Subscribe**.
2. Launch BO3 normally (not via Launcher). Zombies → Custom Games → your map.
3. Play a round.

**All green?** That's the e2e proof: repo → sync → compile → run → publish →
subscribe → play. Log it in CHANGELOG and start Phase 2 greyboxing in Radiant
(remember: `-Reverse` sync after every Radiant session).

## Known risks (authored on macOS, unverified on real Mod Tools)

Honesty section - **substantially shrunk by the 2026-06 stock-API
verification pass** (see [19_stock_api_verification.md](19_stock_api_verification.md):
211 claims verified against the real Treyarch sources, 52 issues found and
fixed, every fix carrying a `VERIFIED(acc)` citation in code). Resolved and
removed from this list since then: module-subfolder resolution (shipped maps
prove it works - keep the layout), the sound zone line (shipped maps ship our
exact combination), file-local `#define` (stock does the same), and the bulk
of the old `TODO(acc-verify)` sites (down to 8, all Phase 3/4 stubs).

What genuinely remains unverifiable from macOS, in order of likelihood:

1. **GDT-level weapon names** - the marketing-name → class-name mapping for
   ICR-1/`ar_accurate`, XR-2/`ar_longburst`, Drakon/`sniper_fastsemi`,
   Locus/`sniper_fastbolt` comes from mod tools GDT naming conventions, not
   the script sources. The shotguns are script-corroborated. Confirm the
   AR/sniper four in APE or the weapon CSV on first compile (comments mark
   the spots in `_acc_map_randomizer.gsc`).
2. **Linker/compile environment quirks** - asset extraction state, language
   packs, disk layout. Mechanical fixes, all covered by the Step 3 table.
3. **Runtime feel** - pacing multipliers, ability chord ergonomics, the
   ADS+melee debounce. Playtest territory, not correctness.
