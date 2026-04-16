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
| `-Reverse` | Pull changes from Mod Tools back into the repo (useful if you edit inside `usermaps\` by accident). |

### What gets synced

| Source (repo) | Target (Mod Tools) |
|---|---|
| `maps\zm\` | `usermaps\zm_abandoned_cyber_city\maps\zm\` |
| `scripts\zm\zm_abandoned_cyber_city\` | `usermaps\zm_abandoned_cyber_city\scripts\zm\zm_abandoned_cyber_city\` |
| `zone_source\` | `usermaps\zm_abandoned_cyber_city\zone_source\` |
| `ui\` (when it exists) | `usermaps\zm_abandoned_cyber_city\ui\` |

### What is NOT synced

- `.map` Radiant files - those are authored in Radiant and live in the Mod Tools tree only. To bring one into the repo for safekeeping, copy it manually into `maps\zm\` and commit (use Git LFS if >5 MB).
- Compiled fast files (`.ff`) - build artifacts, gitignored.
- Stock `share\raw\` assets - never touch.

### Prerequisites

- Windows PowerShell 5.1+ (ships with Windows 10/11).
- `robocopy` (also ships with Windows).
- Mod Tools installed; the `usermaps\zm_abandoned_cyber_city\` folder must already exist (created once via Launcher "New Map").

### Troubleshooting

- **"Could not auto-detect Mod Tools install"**: pass `-ModToolsRoot` explicitly.
- **"Target does not exist"**: you haven't created the map in Launcher yet. Do that first (see `SETUP_WINDOWS.md` step 3).
- **Script won't execute** ("execution policy" error): run PowerShell as admin once and execute `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`. This is standard Windows PowerShell gating; our script is unsigned.

## Future tools (planned)

- `lint_gsc.ps1` - grep for `TODO(acc-verify)` and related markers, produce a report.
- `pack_workshop.ps1` - orchestrate the full Launcher build + Workshop publish from the command line, once we automate that.
- `extract_stock_ref.ps1` - copy relevant portions of `share\raw\scripts\zm\` into a local reference folder for grepping, without polluting the repo.
