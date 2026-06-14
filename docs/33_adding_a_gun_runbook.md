# 33 — Adding a box gun (reusable runbook)

The repeatable recipe for adding a Skye-ported weapon to the map as a box gun
with **all twins, sounds, classification, and balance**. Written while adding the
**BO2 AK-47 (`t6_ak47`)** on 2026-06-14; the worked example at the bottom is that
gun. Companion to docs/32 (the original 3-gun import) and docs/21 (pack sources).

> **Golden rule:** a gun already in the map is the template. Pick the closest one,
> trace how it is wired through the 10 points below, and mirror it. The Five-Seven
> (`t6_fiveseven`) and AK-47 (`t6_ak47`) are both BO2 imports, so they mirror each
> other almost exactly.

---

## 0. Prerequisites — is the asset installed?

The gun's Skye GDT must already be in the Mod Tools install (we do **not** download
multi-GB packs from here — that's a user step, see docs/21 for links). Check:

```powershell
$tools = "C:\Program Files (x86)\Steam\steamapps\common\Call of Duty Black Ops III 455130"
Get-ChildItem "$tools\source_data" -Filter "skye_*.gdt" | Select-Object Name
Get-ChildItem "$tools\model_export\skye_ports" -Directory | Select-Object Name
```

- **GDT filename ≠ weapon (class) name.** `skye_t6_ak47.gdt` → asset `t6_ak47`;
  `skye_s1_tac-19.gdt` (hyphen!) → asset `s1_tac19` (no hyphen). The **weapon name**
  is the asset id inside the GDT, also the `model_export\skye_ports\<name>` folder.
- **Engine prefix = source game** (docs/21): `t6_`=BO2, `s1_`=AW, `iw1_`=CoD4, etc.
- If it is **not** installed, stop — the user must install the pack first. The same
  gun can ship in multiple packs (the AK-47 exists as AW `s1_ak47` AND BO2 `t6_ak47`
  — different guns; confirm which one the user wants).

Read its baked stats now — you need them for balance (step 7):

```powershell
$gdt = "$tools\source_data\skye_t6_ak47.gdt"
Select-String $gdt -Pattern '"(damage|minDamage|fireTime|fireType|clipSize|weaponClass)"\s+"[^"]*"' |
  ForEach-Object { $_.Line.Trim() } | Select-Object -Unique
```

`weaponClass` (rifle/smg/pistol/shotgun/sniper) → the CSV `class`/`weaponVO` and the
ability/overclock family.

---

## The 10 integration points

| # | File | What to add | Auto? |
|---|---|---|---|
| 1 | `gamedata/weapons/zm/zm_levelcommon_weapons.csv` | 1 gun row (`<name>,<name>_up,…`) | manual |
| 2 | `zone_source/zm_abandoned_cyber_city.zone` | `weapon,<name>` + `weapon,<name>_up` | manual |
| 3 | `sound/aliases/acc_skye_box_weapons.csv` | the gun's sound aliases | manual (script) |
| 4 | `_acc_map_randomizer.gsc` `register_mystery_box_pool` | add to `box_weapons` | manual |
| 5 | `_acc_weapon_abilities.gsc` | category + ability table + effect fn | manual |
| 6 | `_acc_overclocks.gsc` `weapon_name_to_family` | add to the family `*_list` | manual |
| 7 | `_acc_damage.gsc` `acc_weapon_balance_mult` | 1 balance line | manual |
| 8 | `tools/apply_recoil_overhaul.js` `GUNS[]` | 1 entry → **re-run** the tool | manual+tool |
| 9 | `_acc_weapon_variants.gsc` `variant_guns()` | add the base name | manual |
| 10| `zone_source/*.zone` twin block | 22 `weaponfull,<name>…` lines | manual |

Steps 8–10 are the **recoil/perk twins** — the thing a casual add forgets. They must
stay in sync: the tool generates the GDT variants, `variant_guns()` allow-lists them,
the zone declares them. A mismatch = a missing-asset link error or a silent twin.

---

## Step-by-step

### 1. Weapon table CSV — `gamedata/weapons/zm/zm_levelcommon_weapons.csv`
Mirror the closest gun's row. Columns: `weapon_name, upgrade_name, hint, cost,
weaponVO, …, in_box(=TRUE), …, class, …`. AR example:
```
t6_ak47,t6_ak47_up,,1250,rifle,,,,,TRUE,FALSE,FALSE,,,FALSE,TRUE,rifle,,,
```
`in_box` value is cosmetic (the box pool is flipped at runtime in GSC); the row's
real job is to load the weapon into `level.zombie_weapons`. `cost` is moot (no
wallbuys; the box charges a fixed price). `weaponVO`/`class` = the `weaponClass`.

### 2. Zone weapon lines — `zone_source/zm_abandoned_cyber_city.zone`
In the box-guns block: `weapon,<name>` and `weapon,<name>_up`. (Dual-wield pistols
also get `_rdw_zm`/`_ldw_zm`/`_rdw_up_zm`/`_ldw_up_zm`; an AR does not.)
**TRAP:** the PaP form in the zone is `_up` (NOT `_up_zm`) for these Skye imports —
match the existing gun lines exactly.

### 3. Sound aliases — `sound/aliases/acc_skye_box_weapons.csv`
Find the alias names the GDT expects and the wavs that exist:
```powershell
Select-String "$tools\source_data\skye_t6_ak47.gdt" -Pattern 'wpn_t6_ak47[a-z_]*' -AllMatches |
  ForEach-Object { $_.Matches.Value } | Sort-Object -Unique
Get-ChildItem "$tools\sound_assets\skye_ports\t6_ak47" -Recurse -Filter *.wav |
  ForEach-Object { $_.FullName.Substring($_.FullName.IndexOf("skye_ports")) }
```
Typical set: `_shot_plr`/`_shot_npc` + `_pap_shot_plr`/`_pap_shot_npc` (fire) and a
handful of foley (`_charge`/`_mag_in`/`_mag_out`/`_bolt_*`/`_futz`). `_plr` and `_npc`
both point at the same `_shot.wav`. **Don't hand-type the ~100-column rows** — clone
existing template rows and swap only Name (col 0) + FileSpec (col 3). The ASM1 fire
rows + Five-Seven foley rows are the templates (see the worked example for the exact
PowerShell). The `.wav` files are already installed by the pack; you only add aliases.

### 4. Box pool — `_acc_map_randomizer.gsc::register_mystery_box_pool`
Add the name to the `box_weapons` array. The clear/re-flag loop + the
`CustomRandomWeaponWeights` filter are generic — no other change.

### 5. Ability — `_acc_weapon_abilities.gsc`
Each weapon **category** has one live signature ability. To add a category:
- `weapon_name_to_ability_category()` — add a `<class>_list = array("<name>")` and an
  `if (array::contains(...)) return "<category>";`.
- `build_ability_table()` — `t["<category>"] = ability("<id>", <cd_sec>, &<effect>);`.
- The **effect fn** must be LIVE (self-contained or using a `_acc_damage` contract).
  Reusable contracts: `self.acc_ability_crit_shots` (N auto-crit shots at 4×) and
  `self.acc_ability_slug_next` (next shot 3×). Don't map to a stub
  (`effect_stabilizer`/`_triple_tap`/`_thermal_vision` are Phase-4 inert).
  Cheapest live new ability = arm `acc_ability_crit_shots` to a count that fits the
  gun (the AK's **Focus Fire** = 6, vs the pistol's Precision Mode = 3).

### 6. Overclock family — `_acc_overclocks.gsc::weapon_name_to_family`
Add the base name to the matching `*_list` (`ar_list`/`smg_list`/`sg_list`/…). The
family **pools** (`build_family_pools`) are already populated for ar/smg/shotgun/
sniper/lmg — no pool edit needed.

### 7. Balance — `_acc_damage.gsc::acc_weapon_balance_mult`
One substring line: `if (IsSubStr(weapon_name, "<name>")) return <mult>;`. This is a
flat per-gun damage scale covering base + `_up` + every `_acc_*` twin in one match.
**Method:** the map is HARD + reward-progress, so equalize *effective* output across
the box. Compute raw DPS = `damage / fireTime` and pick a multiplier that lands the
gun in the intended tier relative to the others. Current anchors (2026-06-14):
Five-Seven ×0.375, ASM1 ×0.2625, Tac-19 ×0.75, AK-47 ×0.23. Headshot exclusion
(`is_weapon_headshot_excluded`) is **shotgun-only** (Tac-19) — ARs/SMGs/pistols get
the ~3× headshot chain, so leave them out of it.

### 8–10. Perk twins (recoil / Gun Slinger / Speed Cola)
1. `tools/apply_recoil_overhaul.js` — add to `GUNS[]`:
   `{ gdt: "skye_t6_ak47.gdt", base: "t6_ak47", up: "t6_ak47_up" },`
2. `_acc_weapon_variants.gsc::variant_guns()` — add the base name.
3. **Run** `node tools/apply_recoil_overhaul.js`. It is idempotent: scales the base
   GDT ×2.5 recoil in place (keeps a `.acc-orig` backup), emits all 22 twins (11
   combos × base/_up) into `source_data/acc_weapon_variants.gdt`, deploys it, AND
   runs `gdtdb /update`. (`build_available_twins()` is suffix-driven off
   `variant_guns()`, so it needs no per-gun edit.)
4. Zone twin block — add the 22 `weaponfull,<name>…` lines (mirror an existing gun's
   block exactly; order: fastfire, fastfire_fastreload, fastreload, recoil35[,…],
   recoil70[,…] × base then `_up`). Update the matrix header count
   (`N = 11 combos × <#guns> × base/_up`).

---

## Build & verify

```powershell
cd <repo>
node tools/lint_gsc_xref.js                      # GSC cross-refs resolve
node tools/apply_recoil_overhaul.js              # twins + gdtdb (step 8)
.\tools\sync_to_modtools.ps1                      # repo -> usermap (+ share\raw aliases, see gotcha)
& "$tools\bin\linker_modtools.exe" -language english -modsource zm_abandoned_cyber_city
```
- **No geometry changed** → linker only (no `cod2map64`/LED). gdtdb already refreshed
  by the recoil tool.
- **Expected exit = `1000000`** (the one user-waived Five-Seven PaP camo
  `mtl_origins_camo_alt`). The shell shows it truncated to **64** (1000000 mod 256).
  Each *additional* `ERROR:` adds another `1000000` — grep the log and resolve any
  that are not the known camo.
- **FF** at `usermaps\zm_abandoned_cyber_city\zone\zm_abandoned_cyber_city.ff` — confirm
  a fresh `LastWriteTime` and a size bump (the AK added ~4 MB: 24.98 → 29.26).
- In-game (`PLAY_TEST_MAP.bat`, `+set_gametype zclassic`): spin the box, confirm the
  gun appears, **fires with sound**, PaPs, and its ability fires on the ADS+melee chord.

---

## Gotchas (hard-won)

- **Sound aliases must be in `share\raw\sound\aliases\`, not just the usermap.** The
  linker's sound-bank build reads the canonical `share\raw` path; the usermap copy is
  ignored at sound-compile. A cached `.all.alias.sz` hides a missing/stale source
  until **any** source changes — then the WHOLE bank fails to load
  (`sound aliases failed to load`) and every gun goes silent. The szc references
  `user_aliases.csv` + `acc_skye_box_weapons.csv` + `nsz_brutus.csv` (aliases) +
  `ambient_mod.csv` (in `share\raw\sound\ambients\`) — **all** must be present.
  `sync_to_modtools.ps1` now copies `sound/aliases/*.csv` → `share\raw\sound\aliases\`
  for you (COPY, not mirror, so stock sources survive). Verify after sync.
- **GDT filename ≠ weapon name** (`skye_s1_tac-19.gdt` → `s1_tac19`). Use the asset
  id everywhere in script/zone/CSV.
- **PaP `_up` in zone/CSV, the variant tool, and balance** all key off the base name
  via substring/`_up` suffix — one balance line and one `variant_guns()` entry cover
  base + PaP + all twins.
- **PaP camo errors are non-fatal and waived** (the Five-Seven's). A new gun whose PaP
  camo table is self-contained in its GDT (the AK's `t6_camo_ak47_table`) resolves
  fine and adds no error. Don't chase camo (user call).
- **Ported energy/sci-fi guns can reference FX from a DIFFERENT game's pack.** The AW
  AE4's muzzle flash is `iw7_efx_plasma_muz_flash` (an *Infinite Warfare* FX). With the
  IW pack absent, the linker logs `Material <fx> not found in gdtDB` — **non-fatal, same
  class as the camo waiver**: the gun fires/sounds/damages, only that one VFX is missing.
  Fix only if you care: repoint the FX field in the gun's GDT to a stock muzzle FX, or
  install the source game's pack. Each such miss adds ~1,000,000 to the linker exit code.
- **Convertible / dual-mode weapons (`altWeapon`) need ALL assets + skip the twins.** The
  Ghosts Ripper is 4 GDT assets (smg/ar × base/_up) linked by `altWeapon` (weapon-switch
  toggles mode). Wire ALL 4 `weapon,` zone lines (the altWeapon targets must resolve), but
  only the **primary** (`inventoryType "primary"`) goes in the box/CSV. The `_zm` trap
  bites: the CSV/box use the bare name (`iw6_ripper_smg`), the zone uses the `_zm` asset
  names — follow the pack's ADD-TO files verbatim. Do NOT add it to `variant_guns()` / the
  recoil tool (a perk-twin swap breaks the altWeapon toggle). One `IsSubStr` balance entry
  covers all 4 assets; map every mode-name in the ability/overclock lists so both modes work.
- **gdtdb.exe is at `<tools>\gdtdb\gdtdb.exe`** (NOT `bin\`); the recoil tool runs it.
- **Skye pack zips can be Deflate64** (.NET extractor fails) — extract with WinRAR
  (`C:\Program Files\WinRAR\WinRAR.exe`).
- **Reproducibility gap:** the Skye GDTs + their `.acc-orig` backups + the per-gun
  base-recoil ×2.5 edit live **install-side** (`source_data\`), not in the repo. Only
  `acc_weapon_variants.gdt` (the twins) is repo-tracked. A fresh box needs the packs
  re-installed and `apply_recoil_overhaul.js` re-run.

---

## Worked example — BO2 AK-47 (`t6_ak47`), 2026-06-14

Full-auto AR box gun. Stats from the GDT: damage 200 (min 175), fireTime 0.08
(750 RPM), clip 30, `weaponClass rifle`. Wiring applied:

1. CSV: `t6_ak47,t6_ak47_up,,1250,rifle,,,,,TRUE,FALSE,FALSE,,,FALSE,TRUE,rifle,,,`
2. Zone: `weapon,t6_ak47` + `weapon,t6_ak47_up`.
3. Sounds (10 aliases) — cloned from templates:
   ```powershell
   $csv = "<repo>\sound\aliases\acc_skye_box_weapons.csv"
   $text = [System.IO.File]::ReadAllText($csv).TrimEnd("`r","`n")
   $lines = ($text -split "`n") | ForEach-Object { $_.TrimEnd("`r") }
   function Get-Row($n){ $lines | Where-Object { ($_ -split ',')[0] -eq $n } | Select-Object -First 1 }
   function Clone($t,$nm,$sp){ $c=(Get-Row $t)-split ','; $c[0]=$nm; $c[3]=$sp; ($c -join ',') }
   $new = @()
   $new += Clone 'wpn_s1_asm1_shot_plr'     'wpn_t6_ak47_shot_plr'     'skye_ports\t6_ak47\fire\wpn_t6_ak47_shot.wav'
   $new += Clone 'wpn_s1_asm1_shot_npc'     'wpn_t6_ak47_shot_npc'     'skye_ports\t6_ak47\fire\wpn_t6_ak47_shot.wav'
   $new += Clone 'wpn_s1_asm1_pap_shot_plr' 'wpn_t6_ak47_pap_shot_plr' 'skye_ports\t6_ak47\fire\wpn_t6_ak47_pap_shot.wav'
   $new += Clone 'wpn_s1_asm1_pap_shot_npc' 'wpn_t6_ak47_pap_shot_npc' 'skye_ports\t6_ak47\fire\wpn_t6_ak47_pap_shot.wav'
   foreach ($f in 'bolt_back','bolt_forward','charge','futz','mag_in','mag_out') {
     $new += Clone 'wpn_t6_fiveseven_charge' "wpn_t6_ak47_$f" "skye_ports\t6_ak47\foley\wpn_t6_ak47_$f.wav" }
   # append $new, write back UTF8-no-BOM with LF
   ```
4. Box pool: added `"t6_ak47"` to `box_weapons` (now 4 guns).
5. Ability: new category `ar` → **Focus Fire** (`effect_focus_fire`, 25 s cd) arming
   `ACC_FOCUS_FIRE_CRIT_SHOTS = 6` (reuses the Precision Mode crit-shots contract).
6. Overclock: `ar_list = array("t6_ak47")` → the AR pool (Burst Coil/Overpressure/…).
7. Balance: `if (IsSubStr(weapon_name,"t6_ak47")) return 0.23;` — sits just above the
   ASM1 sustained; the strongest-but-not-trivial box reward (AR workhorse).
8–10. Twins: added to `GUNS[]` + `variant_guns()`, re-ran the tool (22 AK twins, base
   ×2.5, gdtdb), added 22 `weaponfull,t6_ak47…` zone lines (matrix → 88 = 11×4×2).

Result: `lint xref OK`, linker exit `1000000` (waived camo only), FF 29.26 MB.
