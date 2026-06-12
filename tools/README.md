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
| `zone\` | `usermaps\zm_abandoned_cyber_city\zone\` | copy only - Launcher writes `workshop.json` and publish artifacts here; we must never delete them |
| `map_source\zm\zm_abandoned_cyber_city.map` | `<BO3 root>\map_source\zm\` | single-file copy - Radiant reads map sources from the game root; that folder also holds `_prefabs\` and other maps, so it is never mirrored |

### What is NOT synced

- Compiled fast files (`.ff`) and the `zone_out\` build output - build artifacts.
- Stock `share\raw\` assets - never touch.

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
