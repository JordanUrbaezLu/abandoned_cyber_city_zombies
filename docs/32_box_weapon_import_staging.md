# 32 - Box weapon imports (Five-Seven / ASM1 / Tac-19 / AK-47 / AE4 / Ripper)

> **To add ANOTHER gun, use the reusable runbook: docs/33.** This doc is the
> historical record of the original import + the pack-source / install reference.

Status (2026-06-14): **FINAL — built, in the box, with sound.** The map has **6 box
guns**, all Skye imports:
- **Five-Seven** `t6_fiveseven` (Skye BO2) — the **starting pistol** (set in
  `_acc_main::init` via `level.start_weapon`) AND a box gun.
- **ASM1** `s1_asm1` (Skye AW) — box.
- **Tac-19** `s1_tac19` (Skye AW) — box.
- **AK-47** `t6_ak47` (Skye BO2) — box, **full-auto AR** (added 2026-06-14 via
  docs/33; balance ×0.23, ability Focus Fire, AR Overclock family).
- **AE4** `s1_ae4` (Skye AW) — box, **directed-energy AR** (added 2026-06-14; balance
  ×0.22, native penetration, shares the AR Focus Fire ability + AR Overclock pool).
- **Ripper** `iw6_ripper` (Skye Ghosts) — box, **convertible SMG⇄AR** (added 2026-06-14;
  balance ×0.25, Whirlwind ability + SMG Overclock pool, 4 `altWeapon` assets, NO twins).

The box returns ONLY these six. **Locus / ICR / Man-O-War / FN FAL** are out. All 6
guns built + packed + have sounds. `.ff` = 30.18 MB. The only remaining non-fatal
cosmetic warning (user-waived) is the Five-Seven PaP camo `mtl_origins_camo_alt`.

> **AE4 + Ripper muzzle/shell FX — FIXED install-side 2026-06-15.** The AE4's base
> muzzle-flash FX (the missing IW7 material `iw7_efx_plasma_muz_flash`) and the Ripper's
> shell-eject FX (a `ffx\` path typo in its GDT) were repaired in the install-side Skye
> assets — both now resolve and render. Full recipe (exact files/lines/backups) in
> docs/33 "FIX APPLIED — AE4 + Ripper FX". Install-side only (not repo-tracked), so a
> fresh box must re-apply them — same reproducibility caveat as the AK-74u altWeapon edit.

### History (superseded)
An earlier pass had the box = Tac-19/Locus/FN-FAL/AK-47, then cut to 3 guns
(Five-Seven/ASM1/Tac-19); the **AK-47 (BO2 `t6_ak47`) was re-added 2026-06-14**.

## Build = headless after all (corrects earlier note)
There IS a GDT-convert CLI: **`<tools>\gdtdb\gdtdb.exe /update`** (NOT in `bin\`).
The full weapon-import build sequence (what the Launcher's Compile runs) is:
`gdtdb.exe /update` → `cod2map64` → `radiant LED` → `linker_modtools`. So a future
sound/import rebuild can be done headlessly (geometry unchanged → gdtdb + linker only).

## Known non-fatal warning (FN FAL PaP camo)
Build logged one red but non-fatal error and continued:
`ERROR: Material mtl_origins_camo_alt was not found in gdtDB` →
`weaponcamo: t6_camo_fal_table` → `weapon: t6_fal_up`. The Skye BO2 FAL's
**Pack-a-Punch camo** references a BO2-Origins camo material the pack didn't bundle.
Effect: only the **PaP'd FN FAL's camo skin** is missing (shows default/untextured);
base FAL + all other guns fine. Fix options (when desired): repoint/strip the FAL's
PaP `weaponcamo` in `source_data\skye_t6_fal.gdt`, or supply `mtl_origins_camo_alt`.

## Test now
Launch `PLAY_TEST_MAP.bat` (`+set_gametype zclassic`), spin the box ~6×: only
Tac-19 / Locus / FN FAL / AK-47 should appear. Guns fire **silently** (sound deferred).

This doc is the shopping list + the exact wiring to flip once the Skye weapon
packs are installed on the Windows box. Pipeline facts cross-ref docs/21
(sources) + docs/22 (integration technique) + docs/05 (roster/tuning).

## The 4 target guns

| Gun | Class name | Source | Status |
|---|---|---|---|
| **Tac-19** | `s1_tac19` | Skye **AW pack** | import — needs assets |
| **Locus** | `sniper_fastbolt` | **stock BO3** | ✅ LIVE in box now (no import) |
| **FN FAL** | `t6_fal` (semi-auto) | Skye **BO2 pack** | import — needs assets |
| **AK-47** | `s1_ak47` (AW) **or** `t6_ak47` (BO2) | Skye AW or BO2 pack | import — confirm which on install |

> The AK-47 ships in both the AW and BO2 packs. Whichever lands, note its exact
> name (look in `source_data/` for `skye_s1_ak47.gdt` vs `skye_t6_ak47.gdt`) and
> use that name everywhere below. The GSC classification tables already list
> **both** `s1_ak47` and `t6_ak47` (inert until one exists), so abilities/
> overclocks work regardless; only the box FINAL array needs the one real name.

## Downloads (verified live 2026-06-12, docs/21 + research dossier)

Get from **TheSkyeLord's BO3 weapon ports** (credit required — see bottom).
Master hub (source of truth / current links if any below rotate):
<https://www.ugx-mods.com/forum/full-weapons/84/skyes-weapon-ports-to-bo3-master-hub/16874/>

**Full packs (recommended — each bundles that game's "Weapon Common"):**
- **AW pack** (gives Tac-19 `s1_tac19` + AK-47 `s1_ak47`):
  `https://mega.nz/file/BbJjmKSB#K9k-S_odfssjY1n6vF0bYg0WK390788PUxQZBIxyUtw`
- **BO2 pack** (gives FN FAL `t6_fal` + AK-47 `t6_ak47`):
  `https://mega.nz/file/JXRnAKyB#TxIt1n5FsS87n8Ak9NmT-xO3Zpr79DhzANqvwZBEd0U`

**Individual installers (smaller, but each needs that game's Weapon Common separately):**
- Tac-19 (AW): `https://mega.nz/file/1LpEVQKZ#YimlbI3qYT2O9saFTnqig4MuMVBTov515HSJ-4tNKvQ`
- FN FAL (BO2, semi-auto): `https://mega.nz/file/9DhTjQDI#HUwY_qw2YjILABDTxawtHrmrDQQYJ-C9KnVtsXb2yD0`
- (AK-47 has no clean AW/BO2 individual link — easiest via a full pack above.)

**Wiring template (GitHub — the exact CSV rows + zone lines per game):**
- `https://github.com/FanaticSoftware/Skye-Weapon-Templates/releases/download/WpnTemplates-v1.04/Fanatic-SkyeWeaponTemplates.v1.0.4.rar`
  (AW template = `rex/templates/.../03. ZM - AW/`, BO2 = `04. ZM - BO2/`.)

If any Mega link is dead (error -9/-16), pull the current link from the master
hub thread. The packs are Mega/iCloud hosted — there is no GitHub asset mirror.

## Install (Windows box, per pack)

1. Extract each pack to the **BO3 root**
   `C:\Program Files (x86)\Steam\steamapps\common\Call of Duty Black Ops III 455130\`
   — folders merge into `model_export`, `xanim_export`, `source_data`,
   `sound_assets`, `share\raw`, `map_source\_prefabs`.
2. Open the Mod Tools Launcher once (or run `gdtdb.exe`) so the new `source_data`
   GDTs register.
3. Tell me the exact AK-47 name that landed (`s1_ak47` vs `t6_ak47`).

## Wiring to apply once assets are installed (I do this)

1. **Custom level weapon CSV** — create
   `usermaps/zm_abandoned_cyber_city/gamedata/weapons/zm/zm_levelcommon_weapons.csv`
   (override at the stock path; the linker uses the usermap copy). Copy the stock
   header + the `sniper_fastbolt` row, and copy the `s1_tac19` / `t6_fal` /
   `<ak>` rows from the matching Skye template CSV. `in_box` value doesn't matter
   (register_mystery_box_pool flips it at runtime); the row's job is to load the
   weapon into `level.zombie_weapons`.
2. **Zone lines** — in `zone_source/zm_abandoned_cyber_city.zone`, after the
   `stringtable,...zm_levelcommon_weapons.csv` line, add per import (NOT Locus):
   `weapon,s1_tac19` / `weapon,s1_tac19_up_zm`, `weapon,t6_fal` /
   `weapon,t6_fal_up_zm`, `weapon,<ak>` / `weapon,<ak>_up_zm`.
   **TRAP (docs/22):** the zone upgrade asset carries `_zm` (`..._up_zm`) but the
   CSV `upgrade_name` column does NOT (`..._up`). Match each against the Skye
   template `.zone`/CSV exactly.
3. **Sound** — copy `skye_s1_weapons.csv` + `skye_t6_weapons.csv` into
   `share/raw/sound/aliases/`, and add a `Sources` ALIAS entry for each to
   `sound/zoneconfig/zm_abandoned_cyber_city.szc` (template syntax in the Skye
   per-game `.szc`).
4. **GSC** — in `_acc_map_randomizer.gsc::register_mystery_box_pool`, replace the
   INTERIM `box_weapons` array with the FINAL block (already written as a comment
   right below it): `s1_tac19`, `sniper_fastbolt`, `t6_fal`, `<ak>`. The ability/
   overclock/damage tables are already pre-wired (`_acc_weapon_abilities.gsc`,
   `_acc_overclocks.gsc`, `_acc_damage.gsc` Tac-19 headshot exclusion).
5. **Build** — new assets → full rebuild: sync → `cod2map64` → LED → `linker`.
   Watch for `missing source checksum` (sound) and `Unresolved external <name>`
   (a CSV/zone name typo or the pack not extracted to root).
6. **Credit** — add "TheSkyeLord — weapon ports" to the Workshop description
   (and LilRobot if inspect anims are added). No reupload of the packs.

## Verify in-game
Launch `+set_gametype zclassic`, spin the box ~6×: only Tac-19 / Locus / FN FAL /
AK-47 should appear, each fires/reloads/PaPs, no `missing material/xmodel` spam
for these names in `console_mp.log`.

## What's DONE (installed + wired + deployed)
- **Packs installed** to the Mod Tools root (AW pack via WinRAR — its zip uses
  Deflate64 which .NET can't read; BO2 pack via .NET). GDTs in `source_data\`:
  `skye_s1_tac-19.gdt`, `skye_t6_fal.gdt`, `skye_t6_ak47.gdt` (+ models/anims/sounds).
- **Custom weapon table**: `gamedata/weapons/zm/zm_levelcommon_weapons.csv` = the
  stock 50-weapon table + the 3 import rows (verbatim from each pack's
  `ADD TO ZM_LEVELCOMMON_WEAPONS.txt`). Deployed as the usermap override.
- **Sync**: `tools/sync_to_modtools.ps1` now mirrors `gamedata/` (copy, not /MIR).
- **Zone**: 6 `weapon,` lines (`s1_tac19`/`_up`, `t6_fal`/`_up`, `t6_ak47`/`_up`).
- **Box GSC**: `register_mystery_box_pool` FINAL array = `s1_tac19`, `sniper_fastbolt`,
  `t6_fal`, `t6_ak47`. Ability/overclock/damage tables already pre-wired (incl. both
  `s1_ak47`+`t6_ak47` so either AK works); old `<name>_zm` family names purged.
- **Deployed** to the usermap via sync. `lint_gsc_xref.js` clean.

## REMAINING
1. **Launcher build** (you) — converts the GDTs + links. See NEXT STEP at top.
2. **Sound (deferred, non-fatal)** — each pack ships `ADD TO USER_ALIASES.txt`
   (the `wpn_s1_tac19_*` / `wpn_t6_fal_*` / `wpn_t6_ak47_*` alias rows; .wav under
   `sound_assets/skye_ports/`). To add: create a map alias CSV from those rows and
   add an ALIAS `Source` to `sound/zoneconfig/zm_abandoned_cyber_city.szc`. Skipped
   for now because a malformed sound source can FAIL the whole build, whereas missing
   aliases only make the guns fire silently. Do this after the guns work.
- Cleanup: the AW pack's WinRAR staging dir is at `%TEMP%\acc_aw2` (~2 GB) — safe to delete.
