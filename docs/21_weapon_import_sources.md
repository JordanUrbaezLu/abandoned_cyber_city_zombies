# 21 - Weapon Import Sources (verified 2026-06-12)

Every claim below was verified by a 27-agent research pass (4 sweep angles +
23 adversarial URL verifications, all confirmed live). This doc is the
shopping list + recipe for getting the 7 roster imports (docs/05_weapons.md)
into the map on the Windows box.

## The headline

**One source covers all 7 target weapons: TheSkyeLord's weapon ports**
(791 weapons, APE-ready). And the wiring layer for them is the repo we
already trust as ground truth: `FanaticSoftware/Skye-Weapon-Templates`
(CLAUDE.md "Pristine Launcher zm template" source — it is literally the
template pack designed to pair with Skye's asset packs).

Structural finding: GitHub hosts almost no actual BO3 weapon assets — the
ecosystem distributes APE-ready kits via UGX-Mods/Modme threads with
Mega/iCloud links; GitHub repos carry the wiring (CSVs, zone lines, GSC).

## Per-roster-weapon resolution

| Roster slot | Skye weapon name | Pack | Notes |
|---|---|---|---|
| B23R (starter pistol) | `t6_b23r` | BO2 pack | **Doc correction: B23R is a BO2 weapon, not MW2/MW3** (docs/05 says "Import (MW series)") — individual port verified, includes wallbuy |
| Tac-19 (strong shotgun) | `s1_tac19` | AW pack | verified in AW template CSV + individual Mega link |
| AK-47 (strong AR) | `iw4_ak47` / `t5_ak47` / `t6_ak47` / `s1_ak47` / `h1_ak47` | 6 packs incl. CoD4 | pick one era; CoD4 individual port ships a wallbuy |
| M14 EBR (normal semi-AR) | `iw4_m14ebr` | MW2 pack | individual Mega link verified |
| G3 (bad semi-AR) | `h1_g3` (MWR pack) or CoD4 individual port | **Doc correction: the G3 is NOT a WaW weapon** (WaW has the Gewehr 43; docs/05 says "Import (WAW)") — CoD4 port includes wallbuy + PaP ACOG |
| FN FAL (strong semi-AR) | `t5_fal` (BO1) or `t6_fal` / `t6_fal_osw` (BO2) | BO1/BO2 packs | both individual Mega links verified |
| Intervention (normal sniper) | `iw4_intervention` | MW2 pack | individual Mega link verified |

Naming trap (extends the CLAUDE.md weapon-name rule): Skye names are
engine-prefixed (`iw4_`=MW2, `t5_`=BO1, `t6_`=BO2, `s1_`=AW, `h1_`=MWR),
GDTs are `skye_<prefix>_<gun>` — these are CUSTOM weapons that ride in via
the `zm_levelcommon_weapons.csv` stringtable, distinct from stock class
names (`ar_accurate` etc.). Wallbuy structs just point
`zombie_weapon_upgrade` at the skye name (e.g. `iw4_intervention`).

## Sources (all URL-verified live)

### Assets (the actual guns)

- **Skye's Weapon Ports Master Hub** — UGX-Mods:
  <https://www.ugx-mods.com/forum/full-weapons/84/skyes-weapon-ports-to-bo3-master-hub/16874/>
  (Modme mirror: <https://forum.modme.co/wiki/threads/2565.html>, archived at
  <https://github.com/dtzxporter/ModmeForum/blob/main/wiki/threads/2565.md>).
  Per-game packs: GDTs (`source_data`, all `skye_*`), `model_export\skye_ports`,
  `xanim_export\skye_ports`, sounds, FX (`share\raw\fx\skye_efx`), wallbuy
  chalk prefabs (`map_source\_prefabs\zm\skye_prefabs`). Per-weapon
  individual installers exist for everything in our table. Each game also
  needs that game's **Weapon Commons** (shared textures/sounds — bundled in
  packs, separate for individual weapons).
- Alternatives (verified live, weaker fit): ProRevenge's ports
  (<https://forum.modme.co/wiki/threads/2602.html>), Rico's drag-and-drop ports
  (<https://forum.modme.co/wiki/threads/2240.html>), DEVRAW hub
  (<https://www.devraw.net/>), CabConModding packs. HarryBo21's old gun pack
  (B23R/FAL/AK/M14): **dead links** per the Modme archive — skip.

### Wiring (integration reference)

- **FanaticSoftware/Skye-Weapon-Templates** — 15 per-game Launcher templates;
  each = `map_source` template map + pre-filled
  `gamedata/weapons/zm/zm_levelcommon_weapons.csv` (e.g. MW2 = 43 `iw4_*`
  weapons), entry GSC/CSC, `.szc`, `.zone` with the weapon + stringtable
  lines, plus `share/raw` sound aliases (`skye_<game>_weapons.csv`).
  Latest release: v1.0.4 (2025-03-26),
  `releases/download/WpnTemplates-v1.04/Fanatic-SkyeWeaponTemplates.v1.0.4.rar`.
  **No license file; README requires credit: TheSkyeLord (weapons), LilRobot
  (inspect script).**
- Shipped-map integration examples: `ohm-nabar/zm_building` (largest
  multi-pack roster), `ColDog5044/zm_countryside`, `clixmods/zm_nuked`.
- DIY porting (only if a gun isn't already ported): Modme wiki Weapon-Porting
  guide (<https://wiki.modme.co/wiki/black_ops_3/guides/Weapon-Porting.html>) +
  Greyhound extractor (<https://github.com/Scobalula/Greyhound/releases>).

## Install recipe (Windows box, per pack)

1. Extract the Skye pack to the BO3 root (`Steam\steamapps\common\Call of
   Duty Black Ops III`) — folders merge into `model_export`, `share`,
   `sound_assets`, `source_data`, `xanim_export`, `map_source\_prefabs`.
2. Copy the weapon lines for our 7 guns from the matching template's
   `gamedata/weapons/zm/zm_levelcommon_weapons.csv` into our map's copy
   (create `usermaps/zm_abandoned_cyber_city/gamedata/weapons/zm/` override).
3. Copy the weapon asset lines + keep the `stringtable,` line in
   `zone_source/zm_abandoned_cyber_city.zone` (template `.zone` is the
   reference for exactly which lines each gun needs).
4. Copy `skye_<game>_weapons.csv` sound aliases into `share/raw/sound/aliases`
   and reference the template `.szc` for the sound zone config.
5. Point the wallbuy structs' `zombie_weapon_upgrade` at the skye names
   (one-line .map edits — slots already placed with stock stand-ins).
6. Credit TheSkyeLord + LilRobot in the Workshop description.

Known traps from the hub FAQ: ~150 weapons-per-map practical limit;
wallbuy price-0 bugs = missing the zone stringtable line or CSV ordering.

## Community/legal posture

Porting between CoD titles is community-tolerated on the BO3 Workshop at
scale (thousands of maps; no takedown precedent surfaced). The enforced norm
is **credit the porter**; Skye's threads grant blanket usage with credit.

## Doc follow-ups

- docs/05_weapons.md: fix B23R provenance (BO2, not "MW series" import) and
  G3 provenance (CoD4/MWR port, not WaW) — tracked as checklist items.
