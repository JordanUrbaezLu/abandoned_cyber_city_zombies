# 35 — BO2 → BO3 asset porting pipeline (perk machines, props, mobs)

Tested-against-this-install guide for bringing Black Ops 2 (and any CoD) assets into the
BO3 Mod Tools so the **linker actually packs them**. Written 2026-06-25 from a 4-agent
research pass + verification against this install's shipping `.ff`.

> **THE HEADLINE (this corrects a long-standing project belief):** **This install CAN
> compile + render custom 3D MODEL materials/textures.** An imported BO2 model with its
> own textures renders **fully textured, NOT checker.** Hard proof: the shipping
> `zm_abandoned_cyber_city.ff` already carries **many custom-imported model materials** —
> NSZ **Brutus** (BO2 body/head/gloves/helmet), the DLC3 charred-zombie sentinel
> materials, and the **West Electric Cherry vending machine** — all rendering in-game
> today. (An exact count is not tracked; the material lines live in the `.zone` — grep
> `xmodel,`/`aitype,` and their transitive material deps.) So the "custom materials are
> blocked" warning in **docs/20 §14 is mis-scoped** (it only ever applied to ONE
> brush-FACE reskin that hit a shader-cache miss; model materials always worked). **You
> will NOT get an untextured Electric Cherry machine — and in fact you no longer do.**

## Why model materials work here (the mechanism)
The linker does **not** compile shader HLSL from source (the geometry-shader `.hlsl`
source files aren't shipped — only `image.hlsl`). It resolves each material's **techset**
by pulling a **precompiled `.lz4` permutation** from the shader cache
(`share/assetconvert/ToolsGfx/shaders_modtools/v14/f8/`) by hash. Every standard model
material type (`lit`, `lit_transition`, `lit_advanced_fullspec`, `lit_emissive`,
`lit_decal_*`, …) is **already cached**, so model materials pack with **zero source
compilation** — only the TIF→IWI image compile runs (via `image.hlsl`, which IS present),
and that succeeds. BO2/BO1/AW ports use standard `lit_*` types, so this "just works."

**The ONLY material failure mode:** an exotic material whose techset permutation is NOT
in the cache → the linker tries a fresh source compile → dies on the absent
`gbuffer_lit.hlsl` / `techsetdef_buildshadowmap.hlsl`. **Fix:** re-author that material's
GDT `materialType` to a standard cached `lit_*` type before APE import. Rare for normal
ports. (2D HUD materials ARE genuinely blocked — use the LUI `RegisterImage` path; that's
separate and unrelated to model textures. See `hud-custom-image-lui-not-material`.)

---

## Division of labor
- **YOU (hands-on GUI/3D):** Greyhound extraction, Maya/Blender cleanup (and **rigging** for
  animated characters), APE asset/material setup. **These cannot be done headless** — they're
  the human part.
- **ME (file-side, scriptable):** the `.zone` lines, the GSC wiring, `gdtdb /update`, the
  build, and verification via the assetinfo CSV.

---

## A. Static prop / perk machine (the EASY lane — Electric Cherry)
1. **[YOU · Greyhound]** Load BO2, find the model by name (e.g. `p6_zm_vending_electric_cherry_on`),
   Export Selection. Output: `SEModel`/`.MA`/`xmodel_export` + PNG textures. (BO2 in-game names ≠ asset names.)
2. **[YOU · Maya or Blender]** Clean it. **Maya:** `File > Open` the `.MA` (NEVER drag-drop — it adds a
   namespace that corrupts export); delete unneeded joints; set pivot at the base; re-export
   `xmodel_export` via *Call of Duty Tools > Export XModel*. **Blender (no Maya):** import with the
   Shiversoftdev CoD addon, export `xmodel_export`/`xmodel_bin`.
3. **[FILE-SIDE · the big shortcut] `C3IG`** — drag the `xmodel_export` **+ the textures** onto it: it
   makes the `xmodel_bin`, converts PNG/DDS → **TIFF** (BO3's only accepted source format), AND
   auto-writes a GDT with the xmodel + all materials. (Manual path: `export2bin.exe` + hand-build the GDT in APE.)
4. **[YOU · APE]** Verify the xmodel asset: **Type = RIGID** (a static machine is rigid, NOT animated),
   `LOD0` → the `xmodel_bin`, `BulletCollisionLOD = LOD0`. In **Materials**, every material must be
   created (no yellow `!`), `materialType` = a world type (`lit`/`lit_advanced_fullspec`, **NOT** `lit_weapon`),
   each `colorMap`/`normalMap`/`specMap` → a real **TIFF**.
5. **[FILE-SIDE · me] `gdtdb /update`** + add `xmodel,<name>` (+ its non-stock materials/images) to the
   `.zone` (a vending xmodel is a **non-face** asset, so it DOES need `.zone` lines — the "face materials
   need no `.zone` line" rule is brush-faces only).
6. **[FILE-SIDE · me]** Build. A perk-machine model add touches **no brushes** → **`-GscOnly`/linker-only
   is correct** (no LED bake needed). **Verify it packed via the assetinfo CSV** (`grep material,mc/mtl_<model>`),
   NOT the `.ff` size.

### Electric Cherry — DONE (the model ships)
The perk is fully built (`_acc_perk_electric_cherry.gsc`, on `specialty_combat_efficiency`, own Lab
alcove) **and now renders its real vending machine.** `EC_ON_MODEL`/`EC_OFF_MODEL` = **`electric_cherry_model`**
(`:89-90`), set on `machine_assets.on_model`/`.off_model` in `ec_precache()` (`:150-151`). The model is
the cherry vending machine from the **[West] Community Perk Collection v2.7** external pack (gitignored,
`tools/external_assets_manifest.ps1`), **force-packed** via `xmodel,electric_cherry_model` in the `.zone`
(`:29`) because runtime `SetModel` assets need an explicit line. One model for both power states (the
pack's convention; the powered glow is light FX owned by `_acc_perk_lights`). **No new GSC — the
`p7_zm_vending_nuke` / lab-prop stand-in is retired.**

**Why the BO2 rip was abandoned:** the stock `p6_zm_vending_electric_cherry_on/off` names are
**catalog-listed but have NO packable source in any install** (rendered INVISIBLE, 2026-06-25) — so the
"rip it from Mob of the Dead" plan below is a dead end, kept only as history. The West pack supplied a
real, packable source instead.
- ~~Rip `p6_zm_vending_electric_cherry_on/off` from BO2 Mob of the Dead~~ — no packable source exists.
- ~~Lethal Peelz "Electric Cherry Re-modeled" HD pack~~ — not needed; the West machine ships.

---

## B. Animated mob / reskin (the HARD lane — but the Avogadro is already done)
General reskin ("Avogadro skin that moves like a zombie"):
1. **[YOU · Greyhound]** Rip the **stock BO3 zombie body+skeleton** (this is the rig you bind to) AND the
   BO2 character mesh + textures.
2. **[YOU · Maya]** Import the BO3 zombie rig, **delete its mesh but keep the joints**, import the BO2 mesh,
   align it to the skeleton, **Bind Skin → "Bind to: selected joints,"** then **Copy Skin Weights** from the
   original zombie mesh + clean up by hand.
3. **[YOU · Maya/APE]** Export (meshes **+** joints) → `export2bin` → APE xmodel **Type = animated** (or
   "multiplayer body"), assign materials, set **bulletmesh + hitbox** (or it can't take damage).
4. **[FILE-SIDE · me]** `.zone` the body + materials; in GSC, `self SetModel("<body>")` on a spawned zombie so
   **stock zombie xanims drive it** (the simple/hacky-correct path), or build the Character/Archetype/Spawner chain for a true AI type.

> **Universal failure = T-POSE.** A mesh that's unbound, or bound to the BO2 (wrong) skeleton, or not
> flagged `animated` in APE, compiles + spawns but stands **frozen** — "build-OK ≠ rigged-OK," verify by
> watching it walk. **Maya ≫ Blender for rigged characters** (the Blender 2.79 path mangles UVs/weights).

### Avogadro — DONE (BO3-rigged port integrated as a full boss)
**Dick_Nixon's Avogadro** (from "Bus Depot Reimagined") is a BO3 port — real model on a working actor +
a `zm_ai_avogadro.gsc` control script — and it is **fully wired as a boss** in
`_acc_boss_avogadro.gsc`. It spawns via `SpawnActor("spawner_zm_avogadro", …)` (the LED-bake-safe Rogue
Protector recipe; the pack GDT's archetype→variant→spawner chain is zone-listed) then
`zm_ai_avogadro::avogadro_spawn(boss, true)` runs the pack's zombie setup on the pre-spawned actor
(`:270-289`). He is a ZOMBIE-team aitype (no team flip). It **joins the shared boss roster** as the
`"avogadro"` type via `level.acc_boss_roster_fn` (`:146-148`) and inherits the whole boss-fix stack —
so the round-cadence, spawn-near-player, HP scaling (shares the Phantom curve), and boss-bar wiring all
come for free. **Rigging was NOT needed — the pack shipped a rigged BO3 actor.**
- **Download (history):** `Avogadro.rar` ([modme 2402 "Mike's repertoire"](https://forum.modme.co/wiki/threads/2402.html), MediaFire). Confirmed working — shipped Workshop maps (e.g. "Frequency") embed it.
- **Identity (user 2026-07-04):** not lethal — a fast electric harasser that stun-locks players and
  hacks perk/PaP machines offline (BT-driven bolt throw + point-blank aura; disables up to 2 machines
  for 30s). Full behaviour contract in `_acc_boss_avogadro.gsc`'s header.

---

## Gotchas (all lanes)
- **Greyhound rip ≠ packable.** Loads in a viewer/another game ≠ the BO3 linker can pack it — it needs the
  **SOURCE** (`xmodel_bin` + GDT + TIFF) installed + `gdtdb /update`. Build-verify every port via the
  **assetinfo CSV**, never the `.ff` byte size (it can even shrink). (`greyhound-catalog-not-modtools-packable`,
  `external-weapon-port-add-recipe`.)
- **Do NOT add a `material,<name>` line to the `.zone` for a model's material** — that forces a standalone
  material compile (the source-compile path). Model materials ride in **transitively** as xmodel deps.
- **TIFF only.** Greyhound gives PNG/DDS; convert to TIFF (C3IG auto) or the material ships black/missing.
- **Build with the game CLOSED** (zone/`.sabs` are file-locked).
- **IP:** every BO2 rip is unlicensed Treyarch IP → **gitignored** via `tools/external_assets_manifest.ps1`
  (gated by `check_external_assets.ps1`), and **CREDITS.md IP review before Public Workshop** (CLAUDE.md hard rule). Same bucket as Brutus / Skye guns.

## Tools + sources
- **Greyhound** (extract): https://github.com/Scobalula/Greyhound
- **C3IG** (xmodel_bin + TIFF + auto-GDT, the time-saver): ugx-mods.com thread 14841 · `export2bin.exe` ships in `…455130\bin`
- **Maya + CoDMayaTools** (rig/export) · **Blender + Shiversoftdev CoD addon** (Maya-free)
- **Guides:** [modme: Import models from CoD games](https://wiki.modme.co/wiki/black_ops_3/basics/Import-models-from-Call-of-Duty-games.html) · [modme: Weapon Porting](https://wiki.modme.co/wiki/black_ops_3/guides/Weapon-Porting.html) · [modme: Setting up perk machines](https://wiki.modme.co/wiki/black_ops_3/basics/Setting-up-perk-machines.html) · ZeroY wiki "ZM Models"
- **Downloads:** EC HD pack [modme 2737](https://forum.modme.co/wiki/threads/2737.html) · Avogadro [modme 2402](https://forum.modme.co/wiki/threads/2402.html)

> **TODO (separate, still open):** correct **docs/20 §14** + the `zone_source/zm_abandoned_cyber_city.zone`
> material note (currently ~lines 60-64) — both still say "custom materials blocked" full-stop, but that
> is mis-scoped: model materials always packed (Brutus / charred / EC prove it); only an uncached
> brush-FACE techset permutation fails. See the headline above.
