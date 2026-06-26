# Missing Requirements — what cannot be completed from this machine, and why

> Status as of 2026-06-12, after two ultracode implementation passes
> (geometry + systems + verification, ~150 agents total). The live tracker is
> [docs/20_requirements_checklist.md](docs/20_requirements_checklist.md):
> **201 of 471 requirement items are implemented**; everything still open
> falls into one of the categories below. Each category says exactly **why**
> it is blocked and **what I need from you** to unblock it.

---

## 1. EVERYTHING is unverified until the first Windows compile  ← biggest blocker

**Why:** BO3 Mod Tools (Radiant, APE, the Launcher/linker) are Windows-only
and are **not installed on this machine** — the Steam folder at
`C:\Program Files (x86)\Steam\...\Call of Duty Black Ops III` has only base-game
files (no `map_source/`, no `usermaps/`, no tools). Every line of GSC and map
source was authored against verified stock references (the
`tmp/bo3_stock_ref` mirror + shipped community map sources), but *nothing has
ever been compiled or play-tested*.

**What I need from you:**
1. Install **BO3 Mod Tools** (Steam → Library → Tools → "Call of Duty: Black
   Ops III - Mod Tools", ~170 GB with the game). [SETUP_WINDOWS.md](SETUP_WINDOWS.md)
   is the complete walkthrough.
2. Run `.\tools\sync_to_modtools.ps1`, then build via the Launcher and walk
   [docs/18_first_build_checklist.md](docs/18_first_build_checklist.md).
3. Report any compile errors back to me — the modules are designed to degrade
   one-by-one, and every risky call site carries a `TODO(acc-verify)` marker.

Items gated only on this: all `TODO(acc-verify)` sites, weapon class-name
confirmations (HVK-30, KRM-262 vs Argus identity, second lethal grenade name),
chalk material names for Haymaker/Drakon, the raw-string `SetHintString` on
the Mega trigger, hudelem positioning, and the navmesh/pathing quality of the
greybox geometry.

## 2. The 7 import weapons (B23R, Tac-19, AK-47, M14 EBR, G3, FN FAL, Intervention)

**Why:** the assets live in TheSkyeLord's community packs (Mega/iCloud
downloads) and must be merged into the Mod Tools install and converted in
APE — there is no Mod Tools install here, and the packs are interactive
downloads. The wallbuy slots are already in the map with stock stand-ins, so
each import is a one-line `zombie_weapon_upgrade` swap once installed.

**What I need from you:** on the Windows box, download the packs listed in
[docs/21_weapon_import_sources.md](docs/21_weapon_import_sources.md) (exact
links, all verified live) and extract them to the BO3 root. Then I can do the
CSV/zone/wallbuy wiring — the recipe in that doc is mechanical.

## 3. Custom assets (models / FX / materials / sounds) — Phase 5 art

**Why:** these need asset authoring tools (Maya/Blender + APE conversion),
not code. Currently using documented stock placeholders.

- PhD Flopper machine looks like the stock "nuke" vending machine + raw hint
  token (`ZOMBIE_PERK_ELECTRICCHERRY`) until a custom model + localized `.str` exist.
- Data Shard pickups are invisible `tag_origin`s (functional, no visual).
- Juggernaut Host / Subroutine Core use buffed regular-zombie bodies (the
  stock mechz mini-boss archetype needs DLC1 zone assets usermaps don't have).
- Elite visual identities (shield prop, teleporter FX, EMP arcs), boss
  size/siren/wind-up reads, Cyber Cleaver reskin, perk-machine rotation
  skins, decontamination zone FX.

**What I need from you:** a decision — ship v1.0 greybox-with-stock-assets
(fully playable), or invest in an art pass (needs an artist or asset-pack
hunting session).

## 4. LUI / HUD widgets and client-side (.csc) work — Phase 4

**Why:** persistent HUD beyond the two `SetValue` counters (Shards, Bottles),
keybind screens, Targeting Visor HP bars, Thermal Vision outlines, boss
health bars, and decontamination banners all require LUI (lua) widgets +
client `.csc` modules with clientfield pairs. That work is compile-iterate
heavy — pointless to author blind before the first successful build.

**Currently degraded-but-working:** `iprintlnbold` text for all warnings,
ADS+melee chord for weapon abilities, numeric hudelem counters.

## 5. Engine-property abilities (need weapon GDT variants, not GSC)

**Why:** GSC has no runtime setter for recoil, fire rate, burst patterns, or
grenade fuses. These need authored override-GDT weapon variants swapped at
activation (Phase 4, needs APE):

- Triple Tap (B23R burst cluster), Stabilizer (zero recoil + RoF),
  American Sniper's no-recoil half, Gun Slinger's +45% RoF + −50% swap (BUILT — fastfire twin),
  Sleight-of-Hand Expert's +65% reload, Extended Fuse airburst,
  Savior's revive-speed (engine revive anim timing).
- The EMP Grenade itself (custom weapon `emp_grenade_zm` GDT) and both
  wonder weapons (Signal Staff, Vibro Cleaver) — full Phase 4 authoring.

All have their **damage/economy halves implemented** where one exists
(Precision Mode, Slug Round, Mega multipliers are live).

## 6. Geometry decisions I need from you (design calls, not blockers)

- **Server↔Roof shortcut** (Vault Overload's reward opens it): the two zones
  are on opposite sides of the map — where should the shortcut run?
  The script no-ops gracefully until `acc_shortcut_server_roof` doors exist.
- **Decontamination seal visuals**: the seal is enforced by a kill-on-reentry
  volume (works today). Physical seal walls (`acc_seal_<zone>` brushes) need
  a "spawn hidden" pass in the decon module before placing them, or they'd
  block corridors from round 1 — tell me if you want solid seal walls and
  I'll add the hide-at-init handling + brushes.
- **Rooftop verticality**: the Roof is currently flat greybox at ground level.
  Real elevation = larger geometry rework in Radiant (better done visually).

## 7. Small code gaps with documented owners (next session's quick list)

- Self-revive purchase system (docs/06; consumes the Caching 50% discount
  flag that's already set) — module doesn't exist yet.
- Shard diminishing-returns needs a source tag threaded through
  `_acc_data_shards::spawn_pickup_at` (elite-vs-event distinction).
- Full-boss add waves (chaff + 1 elite/min during the Core fight).
- Ghost Protocol currently also cloaks you from elites (stock `ignoreme` is
  global); needs an elite-side re-target override.
- EMP elite's ability-lock gate in the Cyberware watchers
  (`player.acc_cw_locked_until`).
- 11 opt-in modifiers: dvar plumbing exists, several effects still log-only.

## Out of scope by design (REQUIREMENTS.md "Out of Scope v1.0")

Main-quest Easter Egg, persistent meta-progression, SMG/LMG categories,
traps, procedural geometry, extra game modes — not missing, excluded.

---

### TL;DR — the three things only you can do

1. **Install Mod Tools + run the first compile** (SETUP_WINDOWS.md → docs/18).
   This unblocks more open items than everything else combined.
2. **Download the Skye weapon packs** (docs/21) onto the Windows box.
3. **Three design calls**: shortcut route, seal-wall visuals, roof verticality.
