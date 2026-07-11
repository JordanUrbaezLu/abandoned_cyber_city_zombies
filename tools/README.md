# tools/

Scripts that support the dev loop.

## sync_to_modtools.ps1

Mirrors the authoring trees in this repo into the BO3 Mod Tools `usermaps\zm_abandoned_cyber_city\` folder.

### First-time

```powershell
# In Windows PowerShell, from the repo root:
.\tools\sync_to_modtools.ps1 -DryRun
# review output, then:
.\tools\sync_to_modtools.ps1
```

### Flags

| Flag | Effect |
|---|---|
| `-ModToolsRoot <path>` | Override auto-detected Mod Tools install. |
| `-DryRun` | Print what would change; don't write anything. |
| `-Verbose` | Noisier logging. |
| `-Reverse` | Pull changes from Mod Tools back into the repo. **Run after every Radiant session** so the edited `.map` lands back in the repo. Reverse never deletes repo files. |

### What gets synced

| Source (repo) | Target (Mod Tools) | Mode |
|---|---|---|
| `scripts\` | `usermaps\zm_abandoned_cyber_city\scripts\` | mirror |
| `zone_source\` | `usermaps\zm_abandoned_cyber_city\zone_source\` | mirror |
| `sound\` | `usermaps\zm_abandoned_cyber_city\sound\` | mirror |
| `ui\` | `usermaps\zm_abandoned_cyber_city\ui\` | mirror |
| `fonts\` | `usermaps\zm_abandoned_cyber_city\fonts\` | mirror |
| `localizedstrings\` | `usermaps\zm_abandoned_cyber_city\localizedstrings\` | mirror |
| `vision\` | `usermaps\zm_abandoned_cyber_city\vision\` | copy |
| `gamedata\` | `usermaps\zm_abandoned_cyber_city\gamedata\` | copy |
| `zone\` | `usermaps\zm_abandoned_cyber_city\zone\` | copy only - Launcher writes `workshop.json` and publish artifacts here; we must never delete them |
| `map_source\zm\zm_abandoned_cyber_city.map` | `<BO3 root>\map_source\zm\` | single-file copy - Radiant reads map sources from the game root; that folder also holds `_prefabs\` and other maps, so it is never mirrored |
| `map_source\_prefabs\acc\` | `<BO3 root>\map_source\_prefabs\acc\` | copy (our custom clone prefabs; added 2026-07-10) |
| `sound\aliases\*.csv` | `<tools>\share\raw\sound\aliases\` | copy - the sound-bank compile reads THIS path, not the usermap copy (learned 2026-06-14) |
| `sound_assets\` | `<tools>\sound_assets\` | copy - alias FileSpec paths are relative to the tools root; never purges installed game-rip packs |

### What is NOT synced (other tools own these)

- Compiled fast files (`.ff`) and the `zone_out\` build output - build artifacts.
- Stock `share\raw\` assets are never modified - the ONLY things we write under
  `share\raw\` are our own alias CSVs (table above) and the generated
  `fx\acc\light\*.efx` (via `gen_perk_glow_fx.js`).
- Repo-owned `source_data\*.gdt` deploy via `deploy_source_data.ps1`
  (acc_ssi, acc_weapon_variants; divergence-guarded, `-Reverse` snapshots
  install->repo) and `deploy_perk_shaders.ps1` (perk-shader GDT + custom art).
- Fresh machine? `restore_machine.ps1` chains ALL of the above in order.

### Prerequisites

- Windows PowerShell 5.1+ (ships with Windows 10/11).
- `robocopy` (also ships with Windows).
- Mod Tools installed. The script creates `usermaps\zm_abandoned_cyber_city\` if missing - no Launcher "New Map" step is required because the repo ships the full usermap kit.

### Troubleshooting

- **"Could not auto-detect Mod Tools install"**: pass `-ModToolsRoot` explicitly.
- **Script won't execute** ("execution policy" error): run PowerShell as admin once and execute `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`. This is standard Windows PowerShell gating; our script is unsigned.

## Future tools (planned)

- `lint_gsc.ps1` - grep for `TODO(acc-verify)` and related markers, produce a report.
- `pack_workshop.ps1` - orchestrate the full Launcher build + Workshop publish from the command line, once we automate that.
- `extract_stock_ref.ps1` - copy relevant portions of `share\raw\scripts\zm\` into a local reference folder for grepping, without polluting the repo.
