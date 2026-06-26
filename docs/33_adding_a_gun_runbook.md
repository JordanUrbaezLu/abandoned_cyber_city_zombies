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

**USE THE GENERATOR — `tools/gen_box_weapon_sounds.js` (does fire + foley, 2026-06-15).**
Add the gun to its `GUNS[]` (`{ sid, shot:[…wavs], pap }`) and re-run. It clones the
templates and emits `wpn_<sid>_shot_plr/_npc` (one row per shot-variant wav → randomized)
+ `_pap_shot_*`, **and auto-scans `sound_assets\skye_ports\<sid>\foley\`** to emit one
alias per foley wav (alias name = wav basename = the GDT token). Three traps it encodes:
- **FIRE-ONLY = silent on RELOAD.** The old tool authored only fire rows, so Paladin /
  PPSH / AK-74u fired but had no bolt/mag/charge sound. Foley is not optional — the GDT
  references `wpn_<sid>_mag_in` etc. and a missing alias is just silence.
- **`<sid>` is the SOUND id, which DROPS underscores** for some guns:
  `t9_nail_gun`→`wpn_t9_nailgun`, `t8_paladin_hb50`→`wpn_t8_paladinhb50`. Find it from the
  GDT's actual `wpn_*` token prefix **and** the real `sound_assets\skye_ports\<folder>`
  name — not the weapon asset id. Wrong sid = every sound silent.
- **Cross-named foley** (AK-74u's `wpn_t5_tishina_bolt_back`, in the `t5_ak74u\foley\`
  folder): the auto-scan emits these correctly because it names by wav basename, not sid.
- **Camo/material `wpn_*` tokens are NOT sounds.** A sniper GDT has hundreds of
  `wpn_sniper_<gun>_*scope/camo/lens*` material tokens; only the `wpn_<sid>_*` ones with a
  matching wav are sounds. Driving foley from the wav folder (not the GDT token list)
  sidesteps this automatically.

**Build-time proof the aliases baked in:** the loaded sound bank
`usermaps\…\sound\zone\CachedBanks\all\zm_abandoned_cyber_city.all.sabl` GROWS (adding the
6 guns' fire+foley took it 11.2 → 13.55 MB). Errorlog must show **0** sound/wav lines. A
gun that's still silent in-game with aliases present → check `console_mp.log` line
`SOUND … .all.sabl <N>` loaded OK and that the `<sid>` matches the GDT token exactly.

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

**TRAP — check the GDT's hit-location mults (`loc*`), not just `damage` (balance audit
2026-06-15).** The engine multiplies `damage` by the hit-location field (`locTorsoMid`,
`locHead`, …) **before** `on_ai_damage` sees it, so the *real* body damage = `damage ×
locTorso` and the real headshot = `damage × locHead × our 2.0`. Normal Skye rips ship
`locTorso`=1.0 / limbs=1.0 (verified AK-47, ASM1), so `damage/fireTime` is the true body
metric. **But MP-tuned rips (esp. snipers) inflate ALL loc mults** — the Paladin shipped
`locTorso` 5.0 (PaP 9.0), limbs 4.0, `locHead` 7.5/10.0, so it one-shot *bodies and feet*
to ~r23 at the same balance mult that should have capped it. Fix = **normalize the GDT's
`loc*` mults to 1.0 install-side** (regex-replace the loc fields, `gdtdb /update`, keep a
`.acc-loc-orig` backup — same install-side/not-repo-tracked caveat as the AK-74u altWeapon
edit). Then the additive model holds (body=base, headshot=2×) and the balance mult means
what the DPS math says. **Always grep a new gun's `loc*` block; if `locTorso`≠1.0 it's an
MP rip and the body shot is secretly N× stronger than `damage` implies.**

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
- **Expected exit ≈ `1XXX000`** (known-good baseline, updated 2026-06-15): **1 waived
  `^1ERROR` × 1,000,000 + N cosmetic `^3` warnings × 1,000.** The lone remaining waived
  error is cosmetic-only (gun still fires/sounds/damages): Five-Seven PaP camo
  `mtl_origins_camo_alt`. The `^3` warning count (`N`) **varies build to build** and is
  NOT a regression signal — e.g. a clean GSC-only build logged 13 (`1013000`): 12 are the
  PhD-Flopper Apothicon-Fury FX segments (`dlc4/genesis/fx_apothicon_fury_spawn_in_exp`)
  + 1 bullet-mesh report (`zm_..._bulletreport.csv`), all unrelated to weapons.
  **Errors (2) and (3) in the old `3003000` baseline — the AE4 muzzle FX
  `iw7_efx_plasma_muz_flash` and the Ripper shell-eject FX `h1_shell_eject_57x28` — were
  FIXED install-side 2026-06-15** (see "FIX APPLIED — AE4 + Ripper FX" below); that is why
  the error count dropped 3 → 1. **Method:** don't trust the exit number — read the
  errorlog and confirm the only `ERROR:` is the camo and that **none of your new gun's
  asset ids appear**. A genuinely new error adds another 1,000,000 *and* names your gun.
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
  AE4's muzzle flash chains to `iw7_efx_plasma_muz_flash` (an *Infinite Warfare* material).
  With the IW pack absent, the linker logs `Material <fx> not found in gdtDB` — **non-fatal,
  same class as the camo waiver**: the gun fires/sounds/damages, only that one VFX is
  missing. Each such miss adds ~1,000,000 to the linker exit code. **TRAP:** the broken
  reference is usually NOT the weapon GDT's `viewFlashEffect`/`viewShellEjectEffect` field
  (that points at a `.efx` file that DOES exist) — it's a material/atlas string buried
  *inside* the `.efx` (and its `_efxs` companion) under `share\raw\fx\`. Trace it:
  `grep -rn "<missing-name>" "<tools>\source_data" "<tools>\share\raw"` finds the one real
  site. Fix = repoint that line to an existing sibling material in the same `.efx` (or to a
  stock FX). `.efx` files are raw assets compiled by the linker directly, so a `.efx` edit
  needs only a linker re-run — NO `gdtdb /update` (that is GDT-only).

  **FIX APPLIED — AE4 + Ripper FX (2026-06-15).** Both box guns had a missing-FX `ERROR:`;
  both were repaired install-side (game-rip assets, NOT repo-tracked — see the
  Reproducibility gap gotcha; a fresh box must re-apply, `.acc-fx-orig` backups kept):
  - **AE4 muzzle flash.** `s1_ae4`'s base `viewFlashEffect`/`worldFlashEffect` →
    `fx\skye_efx\s1_efx\fx_s1_fusion_muz_flash.efx` → its `_efxs` companion. In
    `share\raw\fx\skye_efx\s1_efx\fx_s1_fusion_muz_flash_efxs.efx` **one** element
    (a `billboardSprite`, line 884) referenced the missing IW7 material
    `iw7_efx_plasma_muz_flash`; every other element of that same effect already used the
    present sibling `mtl_s1_plasma_muz_flash` (line 308, defined in `skye_s1_wepcommon.gdt`).
    Fix = swap that one line `iw7_efx_plasma_muz_flash` → `mtl_s1_plasma_muz_flash`. Pure
    `.efx` edit → linker re-run only, no gdtdb. (The PaP form already used the working
    `fx_s1_yellow_plasma_muz_flash.efx`.)
  - **Ripper shell eject.** A plain **typo**, not a missing asset: in
    `source_data\skye_iw6_ripper.gdt` line 34705 the PaP-AR form's `viewShellEjectEffect`
    read `"ffx\\_scobalula\\shellejects\\mwr\\h1_shell_eject_57x28.efx"` (`ffx`, double-f)
    while the 7 sibling shell-eject lines correctly said `fx\\`. The `.efx`
    (`h1_shell_eject_57x28.efx`) AND its shell xmodel (`wpn_h1_shell_57x28_npc`) are both
    installed — so the earlier note that "the Scobalula pack lacks the 57x28 variant" was
    WRONG; the only bug was the path typo. Fix = `ffx` → `fx`, then `gdtdb /update` (GDT
    change → `processed (1 GDTs) (87 assets)`).
  - **Verified** by a headless linker re-run: `iw7_efx_plasma_muz_flash` and every
    `57x28`/`ffx`/`shelleject` hit gone from the log; the only `ERROR:` left is the
    Five-Seven camo; fresh 34.26 MB `.ff` written; no new FX/material warnings.
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

## Failure modes — boot crashes & what makes a gun "unsafe" (2026-06-15)

Adding the second wave of 6 guns (PPSH-41, Paladin HB50, AK-74u, Nail Gun, M1911,
PDW) surfaced **three distinct boot-crash classes**. They are independent — each one
alone crashes the load. The hard rule that fell out of it:

> **Add ONE gun at a time, then boot-test before the next.** With 50+ pending edits
> you cannot bisect a black-screen crash after the fact — you add, sync, build,
> launch, confirm, *then* add the next. This is slow and it is the only thing that
> works. "I added 6 and the game won't boot" cost a full revert.

Confirmed-safe roster after this pass: the original 6 + **Paladin HB50** +
**PPSH-41** (both twin-less). Still benched: AK-74u, M1911, PDW, Nail Gun (reasons
below). **Later un-benched (install-side fixes): AK-74u, M1911, PDW, Nail Gun.**

**Added 2026-06-15 — Olympia + Galil (BO2 `t6_olympia`, `t6_galil`), twin-less.** The
cleanest add yet: both pre-screened CLEAN on all three modes — `altWeapon` empty (no §B),
single-wield `bulletweapon` (no §C), twin-less (no §A) — so **no install-side GDT edit**
(unlike AK-74u/Paladin). **Source trap:** the user asked for the **BO1** rips but only
`skye_t5_{olympia,galil}.gdt` were installed — **no models/sounds** (`vm_t5_olympia` +
`wpn_t5_*` referenced but absent on disk). The **BO2** ports (`t6_*`) were fully installed
(model_export + sound_assets), so they were used instead — verify all THREE legs (GDT +
`model_export\skye_ports\<g>` + `sound_assets\skye_ports\<g>`) per Step 0, not just the GDT.
Olympia = shotgun (Slug Round ability, sg Overclock, ×0.85 + headshot-excluded); Galil = AR
(Focus Fire, ar Overclock, ×0.21; loc mults = AK-47, no GDT edit). New guns show only `^3`
xmodel-processing warnings (`N warnings … vm_t6_galil`), never a `^1 ERROR` — those warnings
are normal for ports and harmless.

**Added 2026-06-24 — MK14 (AW `s1_mk14`), the first DMR — FULLY TWINNED, B tier.** Pre-screened clean: single-wield
`bulletweapon`, empty `altWeapon`, all three legs installed (GDT + model + 17 sound wavs). Added with the full twin
treatment via this runbook end-to-end (14 twins → 196 total). Two things specific to a **semi-auto DMR**:
(1) scored as **curated single-target DPS** (`cu:true`, `e=400`) in `compute_gun_tiers.js` — a semi-auto's raw
`damage/fireTime` (300/0.095 ≈ 3158) overstates real DPS, so it's curated like the Five-Seven/Paladin, NOT treated
as full-auto (which would read S); (2) `locHead 6.0` but **body loc clean (1.0)** → **no** Paladin-style loc
normalization (the head mult just yields a ~3× headshot, fitting a marksman). Balance ×0.30 lands it at **B base
AND PaP** (5.90 / 5.99). Sniper ability (Precision Mode) + sniper Overclock family. The screening that caught the
two REJECTED candidates the user first picked: **War Machine** = `projectileweapon` (can't twin, like the Nail Gun)
and **XMG** = permanently-akimbo `dualwieldweapon` (can't twin, like PDW/M1911) — always screen gdf type + akimbo
forms before promising "fully twinned."

### A. Twin weapon-count cap (engine access-violation at boot)

Every recoil/perk **twin** is a full weapon-table registration, so a twinned gun
costs `combos × 2 forms` weapon slots. **Live matrix (slimmed 2026-06-16):** 7 combos
(`recoil50 × fastfire × fastreload`, ammo axis removed) = **14 slots/gun** on **10
guns = 140 twins** (`_acc_weapon_variants.gsc::variant_guns`/`variant_dims`). Pre-slim
it was 23 combos = **46 slots/gun** on 5 guns = 230. The engine has a hard ceiling on
registered weapons and **silently access-violates past it at load** — not a linker
error, the `.ff` builds fine.

- **Live data points (at the old 46 slots/gun):** 5 twinned guns = **230** twins →
  boots; 8 twinned guns = **368** twins → crashes; 9 = 414 → crashes. So the
  twin-layer wall sits between **230 (known-good)** and **368 (known-bad)**; we treat
  **~230 as the safe budget**.
- **Crash signature:** black screen on load → minidump faulting module
  `blackops3.exe`, exception `0xC0000005` (ACCESS_VIOLATION) at
  `blackops3.exe+0x25DF24E`, inside `BG_Cache_RegisterWeapon` during weapon
  registration. **No `console_mp.log` error and no errorlog entry** — the build is
  clean, the engine dies registering the table.
- **CURRENT HEADROOM (2026-06-23) — how many more guns fit:** we are at **140 twins,
  NOT 230** (the slim freed ~90 twins of budget that an old comment hid). So:
  - **Twin-less guns** (the shipped default — base + `_up` = ~2 slots, akimbo = 3, a
    stock-cooked WW like `tesla_gun` = ~0 of *our* budget): cheap, do **not** touch
    the twin budget. Effectively **~10+ more** fit; the only ceiling is the unmeasured
    *total*-table size, so **add ONE at a time and boot-test** — you cannot bisect this
    crash after the fact.
  - **Twinned guns** (full recoil/fire/reload handling): **~90 twins free ÷ 14/gun ≈
    6 more** before the 230 safe line. Hard-stop well before 368.
- **Mitigation we shipped:** new box guns are added with **NO twins** — just the
  base + `_up`, which the box GiveWeapon-swaps as-is. To twin a *new* gun beyond the
  ~6-gun headroom you must first buy back budget (drop another axis — e.g. reload→base
  engine, or the recoil→attachment probe in docs/39 — or retire a gun's twins) so the
  total stays under ~230. `apply_recoil_overhaul.js` tracks the budget math; docs/39
  §0 has the per-axis budget table.
- **Why twin-less is fine:** twins are a polish layer (per-perk recoil/fire-rate
  feel). A twin-less gun still fires, PaPs, sounds, and takes its ability/overclock —
  it just uses one recoil profile across all perk states. Acceptable; ship it.

### B. Attachment `altWeapon` double-`_zm` (`Com_ERROR` on launch) — the AK-74u

The fatal one the user's instinct caught. The BO1 **AK-74u** GDT carries an
under-barrel **launcher** attachment whose `altWeapon` field points at
`t5_ak74u_launcher_zm`. At launch the engine appends its own `_zm` to the *upgraded*
attachment form and looks up `t5_ak74u_launcher_zm_zm` — which does not exist:

```
Com_ERROR: could not find altWeapon 't5_ak74u_launcher_zm_zm'
           for attachment 't5_ak74u_up_zm'
```

This is a **hard `Com_ERROR`, not the silent AV** — it would appear in the runtime
log. The `.ff` links clean (the attachment asset itself resolves); the failure is the
runtime altWeapon name-mangling. **Pre-screen every candidate gun for it:**

```powershell
$gdt = "$tools\source_data\skye_t5_ak74u.gdt"
Select-String $gdt -Pattern 'altWeapon' | ForEach-Object { $_.Line.Trim() }
```

- `altWeapon = ` **empty** → safe (PPSH-41, Paladin both verified empty → both ship).
- `altWeapon = <something>` → that target (and its `_zm`/`_up_zm` forms) **must
  resolve**, or it is benched until the launcher/alt attachment is stripped from the
  GDT. (Distinct from §B-convertibles like the Ripper, where the altWeapon is the
  intended dual-*mode* mechanic and you wire all forms — here it's a vestigial
  attachment we don't want.)

**FIX APPLIED — AK-74u (2026-06-15).** The launcher was a vestigial under-barrel GL we
don't ship, so we severed it install-side instead of wiring the missing weapon:
1. `Select-String skye_t5_ak74u.gdt -Pattern 'altWeapon'` → 3 hits. Only the **PaP
   form** (`t5_ak74u_up_zm`, GDT L10416) carried `"altWeapon" "t5_ak74u_launcher_zm"`;
   the primary (L7839) already ships empty. The exact string is **unique** in the file.
2. Blank it: `"altWeapon" "t5_ak74u_launcher_zm"` → `"altWeapon" ""` (one Edit).
3. Re-bake: `"<tools>\gdtdb\gdtdb.exe" /update` (cwd = the `gdtdb` folder). It
   reprocesses only the changed GDT (`1 GDTs, 109 assets`). **Skipping this = the link
   reads the stale db and the crash persists.**
4. Verify: `Select-String` the GDT for the launcher again (gone) and grep the post-build
   errorlog for `_zm_zm` (**must be 0**). The launcher asset stays in the GDT but is
   never zoned/boxed → vestigial, harmless. This is an **install-side GDT edit** (not
   repo-tracked — see the Reproducibility gap gotcha; a fresh box must re-apply it).

### C. Twin-tool / mechanic exclusions (caught pre-build, not a crash)

`apply_recoil_overhaul.js` only twins `bulletweapon.gdf` assets, and the perk-swap
itself breaks certain mechanics:

- **Projectile weapons** — the **CW Nail Gun** is a `projectileweapon.gdf`; the tool
  aborts `asset "t9_nail_gun" ("bulletweapon.gdf") not found`. Add it twin-less or
  not at all; never put it in `GUNS[]`.
- **Dual-wield / akimbo PaP** — the **M1911** and **PDW** PaP to akimbo
  (`_rdw`/`_ldw` forms). A perk-twin GiveWeapon-swap fights the akimbo state, and
  their PaP form names (`s1_pdw_rdw_up_zm`, `s2_m1911_rdw_up_zm`) don't follow the
  plain `_up` convention the balance/variant substring matching assumes. **NOTE:**
  another pass wrongly set the CSV PaP names to bare `_up` (`s1_pdw_up`, etc.) — those
  forms don't exist; fix the CSV to the real `_rdw_up_zm` name before adding either.

**FIX APPLIED — PDW + M1911 (2026-06-15), twin-less, NO GDT edit.** Akimbo guns are
addable; the catch is the **left-hand partner**:
- The **base is single-wield** (`dualWield 0`); only the **PaP** explodes into a
  `_rdw_up_zm` (right, `inventoryType primary`) + `_ldw_up_zm` (left, `dwlefthand`)
  pair that cross-reference via `DualWieldWeapon`. **Zone ALL THREE forms** —
  `weapon,<g>` + `weapon,<g>_rdw_up_zm` + `weapon,<g>_ldw_up_zm` — or the left hand
  **dangles** when the engine spawns the pair at PaP. (There is no plain `<g>_up`.)
- CSV `upgrade_name` = the **right-hand** form (`<g>_rdw_up_zm`). One `IsSubStr("<g>")`
  balance line + one `weapon_name_to_family` entry cover base + both akimbo forms (the
  OC/balance code keys off the base via `zm_weapons::get_base_weapon`). Do **not** add
  to `variant_guns()`/`GUNS[]` (twins break the akimbo toggle).
- **M1911 explosive-PaP balance trap.** The M1911's PaP forms are *projectileweapons*
  at **7000 direct dmg + splash** (Mustang-and-Sally pattern). `acc_weapon_balance_mult`
  is applied at the TOP of `on_ai_damage` to **all** damage regardless of meansofdeath
  (incl. explosive), so the broad `IsSubStr("s2_m1911") = 3.5` base buff would scale the
  PaP to **~24,500/shot**. Fix: a **more-specific line ABOVE** the base match —
  `if ( IsSubStr(w,"s2_m1911_rdw") || IsSubStr(w,"s2_m1911_ldw") ) return 0.40;` — so the
  explosive forms get their own scale (7000×0.40 = 2800 direct, one-shots ~r20) before
  the broad match. Always check a PaP form's *baked damage* when one `IsSubStr` covers
  base + an explosive/wonder upgrade.

### Boot-crash triage checklist

1. `.ff` built but black screen / instant exit → suspect **A or B**, not the linker.
2. Newest minidump (`%LOCALAPPDATA%\...\Crashes` or the install crash dir): exception
   `0xC0000005` at `blackops3.exe+0x25DF24E` → **A (twin cap)**; revert the last twin
   batch.
3. `console_mp.log` last line is a `Com_ERROR: could not find altWeapon …_zm_zm` →
   **B**; that gun's GDT has a live altWeapon attachment — bench it.
4. Linker abort `asset "<gun>" ("bulletweapon.gdf") not found` → **C**; the gun isn't
   a bulletweapon — pull it from `GUNS[]`.
5. Nothing obvious → revert to the last known-good single-gun state and re-add **one**.

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
