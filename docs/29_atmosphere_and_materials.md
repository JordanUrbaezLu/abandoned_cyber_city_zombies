# 29 — Atmosphere & Materials (wall/floor skins, sky, fog, lighting)

> **Design spec for the map's *look*.** Until now the map is pure greybox (every
> face is the placeholder tool material `script_wall` / `script_floor_ceiling`,
> sky is the flat stock `skybox_default_day`). This doc is the authoritative plan
> for turning that into an **abandoned cyber city**. Per
> [REQUIREMENTS.md](../REQUIREMENTS.md), this doc leads; Radiant/GSC work follows
> it. Pairs with the portable recipe in
> [BO3_MAPMAKING_KB.md](BO3_MAPMAKING_KB.md) (§ Materials, Sky & Fog).

**Status (2026-06-13):** research complete + adversarially verified against the
local Mod Tools install and the shipped `tmp/zm_alien_isolation` source. Phase 1
fog implemented in code ([_acc_atmosphere.gsc](../scripts/zm/zm_abandoned_cyber_city/_acc_atmosphere.gsc));
everything else is the Radiant/APE work scoped below. Branch: `Wallpaper`.

---

## 1. Art direction — the look

**Theme:** a dead high-tech city. Perpetual rainy neon night, dead/flickering
signage, smog, wet reflective ground, decay over chrome. In-engine touchstone:
BO3's own **Shadows of Evil** (low-key noir city, neon contrast). External: Blade
Runner 2049 ruin, Cyberpunk 2077 derelict districts, Observer, Ghostrunner.

**Palette** — ~85% of every surface is dark base; neon is <15% and is the *only*
thing that's bright (the SoE / BR2049 contrast formula):

| Role | Color | Use |
|---|---|---|
| Wet asphalt / near-black | `#0E1115` | dominant ground + deep shadow |
| Cold steel blue-grey | `#2A3340` | structural walls, ducts, server racks |
| Concrete ash | `#3A3A3E` | plaster / brick decay |
| Rust / oxide brown | `#5A3B28` | corrosion streaks, exposed rebar, water stains |
| **Neon cyan** (accent) | `#19E0FF` | "live tech" — working screens, PaP, healthy signage |
| **Neon magenta** (accent) | `#FF2E88` | "dead nightlife" — market signage |
| **Sodium amber** (accent) | `#FF8A1E` | "dying / emergency power" — flickering bulkheads, hazard |

**Lighting principle:** low-key noir. Ambient near-black; almost all illumination
**motivated** by an in-world emissive surface (sign, monitor, sparking cable,
sodium bulkhead). Pools of saturated colored light separated by darkness drive
readability and tension. Flicker is the signature — script-pulse a few emissives
so dead signage stutters.

**Sky / weather / fog:** night, no visible sun disc; perpetual light rain +
drifting smog; thick low fog, cold blue-grey near ground, warming toward amber
where dead power glows. Fog kills sightlines at ~1200–1800u — which also suits
the small-and-dense layout and hides greybox seams cheaply.

---

## 2. Build-vs-buy decision (recommended)

**~90% stock-skin · ~10% custom-authored presets · ~0% bespoke modeling ·
community/CC0 packs only as a Phase-3 fallback after a license check.**

This matches the project's *systems-over-art, time-boxed* posture and is
file-verified against the shipped analog: `zm_alien_isolation` is a full
industrial sci-fi map whose `archetypes` GDT is nearly empty — it ships almost
entirely on **stock materials skinned dark** plus a handful of APE-authored
presets (a LUT, a few sky/emissive assets). We can do the same.

| Surface category | Stance | Why |
|---|---|---|
| **Walls** (546 faces) | **Stock-skin** | dark `t7_concrete_*` / `t7_metal_*`; free, ship-safe, no GDT/.zone work |
| **Floors / ground** (90 faces) | **Stock-skin + reflection probes** | wet `t7_concrete_*_wet` / `t7_asphalt_*_wet`; reflections of neon in wet ground = *the* cyberpunk signal |
| **Sky / fog / grade** | **Stock first, small custom later** | stock `default_night` SSI flips the whole map to night with zero assets; custom LUT/HDRI sky is optional Phase 3 |
| **Neon / emissive signage** | **Custom-author a tiny reusable kit** | 2–3 emissive "dead sign" materials (cyan/magenta/amber), placed repeatedly as landmarks; avoid one-off signs per zone |
| **Props** (racks, ducts, fountain, wreck, machines) | **Stock first** | BO3 ships perk/PaP machines, ducts, pipes, debris, vehicles — all free |
| **Rooftop skyline backdrop** | **Custom, cheap** | 2D/cutout far-tower silhouette — original, no license risk, high payoff |

**The biggest bang for buck** (do these before any per-zone art — ~85% of the
visual payoff for ~15% of the effort): **(1)** night sky via stock `default_night`
SSI, **(2)** cold fog via `SetVolFog`, **(3)** wet stock ground material +
reflection probes, **(4)** one repeated neon motif. See Phase 1 below.

---

## 3. How BO3 atmosphere actually works (verified)

These are the load-bearing technical facts — get them wrong and the build either
fails or silently ships stale. All file-verified against the install +
`tmp/zm_alien_isolation`.

- **A brush face's material token *is* the GDT material name.** In the `.map`, a
  face line ends with the material name (`script_wall` today). At link, `cod2map64`
  bakes that name into the BSP and the linker resolves it from any GDT in the
  Mod Tools project. **Re-skinning = changing that token** (in Radiant's material
  browser, or a bulk find/replace in the `.map` text).
- **Face materials need NO `.zone` line.** Proof: the shipped `zm_alien_isolation`
  `.zone` has **2** `material,` lines despite the map using ~**1017** custom
  materials. **Rule:** a material referenced *by a brush face* auto-pulls from the
  GDT → no line. A material referenced only by **worldspawn / SSI / script / a
  model** (LUT, sky material, sky xmodel, HDR image, script-applied decals, FX) →
  **needs** an explicit `material,` / `image,` / `xmodel,` line, or you get
  "Could not find material".
- **Stock materials are free to ship** (already in installed fastfiles) — no GDT,
  no `.tif`, no `.zone` line, no redistribution concern. The hard part is the
  exact name; confirm in APE / Radiant's material browser.
- **Sky is not a brush material.** It's **(a)** worldspawn `skyboxmodel` (the
  inverted-sphere xmodel drawn at infinity) **+ (b)** the `volume_sun` entity's
  `ssi`/`ssi1`/`ssi2`/`ssi1_runtime_override` keys = *sun-set-info* asset names,
  one per lighting state. An SSI holds its own skyboxmodel, sun color, exposure.
- **Fog is engine-side, separate from sky and vision.** `SetVolFog( startDist,
  halfwayDist, halfwayHeight, baseHeight, r, g, b, maxOpacity )` — 8-arg global,
  **0..1 float** RGB + opacity (stock `load_shared.gsc:807`). Driven from a small
  GSC hook (ours: `_acc_atmosphere.gsc`).
- **A `.vision` file does color-grading ONLY** (tonemap / LUT-like curves) — it
  does **not** create fog. Optional mood polish, applied via `SetVisionSet`.
- **Build-step order matters.** World/material/sky/`volume_sun`/`skyboxmodel`/
  reflection-probe changes are **BSP-baked** → full pipeline: `sync` →
  `cod2map64` → `radiant_modtools -ledSilent +recompute` (**LED relight is
  mandatory** or the new night lighting/reflections won't appear) → `linker`.
  **Pure-script** fog (`SetVolFog`) or a `.vision` rawfile = **linker-only** (no
  cod2map64/LED). New custom GDT assets also need `gdtdb /update` before linking.

---

## 4. Verified stock asset shortlist

`verified` = byte-confirmed present in a GDT on this install / used by a shipped
map. `confirm-in-APE` = name present in the GDT file but exact token spelling to
be confirmed in the APE/Radiant browser before painting. **Confirm every
`confirm-in-APE` name in APE before relying on it.**

| Asset | Category | Status |
|---|---|---|
| `skybox_default_night` | sky xmodel (worldspawn `skyboxmodel`) | **verified** (`t7_techart_props.gdt`) — ZM-safe, no mp_havoc trap |
| `default_night` | SSI (`volume_sun` ssi*) | **verified** (`source_data/ssi.gdt`) — zero-asset night look |
| `skybox_default_black` | alt dark sky xmodel | verified (`t7_skybox.gdt`) — starless fallback |
| `skybox_zm_factory` | alt dark-industrial sky | verified (`t7_skybox.gdt`) |
| `t7_concrete_bare_dark_01_wet` | wall/floor — dark wet concrete | **verified** (`t7_concrete.gdt`) |
| `t7_concrete_floor_garage_cracked_wet_nw` | floor — cracked wet concrete | **verified** — strong wet-ground pick for the 90 floor faces |
| `t7_concrete_poured_bunker_dirty_01_wet` | wall — dirty wet poured concrete | **verified** |
| `t7_concrete_bare_weathered_01` | wall — weathered concrete | **verified** |
| `t7_metal_duct_insulation_01_grey` | wall/duct metal | **verified** — shipped map paints this exact bare token, no `.zone` line |
| `t7_asphalt_damaged_dark_wet` | floor — wet damaged asphalt | **verified** (`t7_asphalt.gdt`) |
| `t7_metal_corrugated_rust` | wall — rusted corrugated metal | confirm-in-APE |
| `t7_brick_worn_dirty_red` | wall — worn dirty brick | confirm-in-APE |
| `t7_glass_dirty_streaks_cracked` | glass curtain wall | confirm-in-APE |
| `t7_zm_der_tile_hexagon` | hex tile floor (corp/lab tech read) | confirm-in-APE (ZM GDT — confirm in installed ZM fastfiles) |
| `luts_t7_default` | current LUT (worldspawn `lutmaterial`) | verified — already in our map; keep until a custom cool LUT exists |
| `zm_factory.vision` | stock dark color-grade rawfile | verified — usable cool grade without authoring a custom `.vision` |

> ⚠️ **Do NOT reuse the `zm_alien_isolation` material vocabulary**
> (`black1_plaster`, `white1_plaster`, `darkblue1_metaldirty`, `ayz_floor`,
> `dark_grey_floortile`, `really_dirty_emissive`, `generic_backlit_ayz`). The
> research's first draft assumed these were stock — **they are not.** They live
> in that author's *custom* GDTs, are absent from our install, would fail to
> resolve as "missing material", and carry no reuse license. Use the `t7_*` names
> above.

---

## 5. Per-zone art direction

Mood + materials per zone (see [03_layout.md](03_layout.md) for the gameplay
graph). All wall/floor picks are stock `t7_*` families; "hero" = the 1–2 surfaces
worth custom emissive/backdrop work.

| Zone | Mood | Walls / floors | Neon accent | Sky | Hero surface |
|---|---|---|---|---|---|
| **Spawn Plaza** | dead transit plaza, first breath of the ruin | grimed concrete + cracked wet pavement | one dead **cyan** district sign; sodium bulkheads | partial (open) | flickering cyan welcome-sign archway; puddle field + reflection probes |
| **Undercity Market** | drowned neon bazaar gone to rot | corrugated metal + plaster, heavy rust; wet tile | densest zone — **magenta** dead stall signage | mostly enclosed | wall of stacked dead magenta ad boards; sparking-cable tangle |
| **Service Alley** | claustrophobic wet utility corridor | dirty metal ducting + pipes; wet concrete runoff | minimal — one failing sodium light + red hazard panel | none | dripping-pipe + steam-vent run w/ single sodium cone |
| **Corporate Plaza** (hub) | lobby of a fallen tech megacorp | ruined polished stone/metal + broken glass curtain wall; dark polished tile | **cyan** corporate logo wall, half-flickering | partial (broken skylight) | giant backlit corp logo over dead fountain; live cyan hack-terminal screen |
| **Server Vault** | cold sealed data-fortress | blue-grey server racks + metal panels; dark grating | sea of tiny **cyan+amber** rack LEDs | none (underground) | server-rack corridor w/ thousands of blinking LEDs; Overload core column (amber pulse) |
| **Rooftop Helipad** | exposed to the dead sky, ruined skyline | wet helipad concrete + faded "H"; low AC units | distant dark skyline + amber edge lights | **maximum** — the sky-reveal payoff | ruined-city skyline backdrop (custom cutout); derelict helicopter wreck |
| **Subterranean Lab** | clandestine cyberware lab, tech still hums | clean-gone-grimy panels + conduit; tech floor w/ under-glow | richest **live cyan+magenta** machine glows (justified — upgrade hub) | none (deepest) | PaP/Overclock terminal cluster glow; Signal Staff craft centerpiece |

Fog is **lighter** in the Corp hub, Vault Overload point, and Lab (readability),
**heavier** in corridors.

---

## 6. Phased plan

### Phase 1 — flip greybox → "cyber city" (fastest, mostly stock, ZM-safe)
1. **Night sky:** in Radiant set the `volume_sun` `ssi`/`ssi1`/`ssi2`/
   `ssi1_runtime_override` to stock **`default_night`**; set worldspawn
   `skyboxmodel` to **`skybox_default_night`**. Confirm nothing reverts to
   `mp_havoc`/`mp_havoc_overide`. *(BSP-baked → full pipeline incl. LED.)*
2. **Fog:** ✅ **implemented** — `_acc_atmosphere.gsc` calls `SetVolFog` after
   blackscreen with a cold low haze (`0, 1600, 600, 0, 0.02, 0.03, 0.06, 0.70`),
   every value live-tunable via `acc_fog_*` dvars (`acc_fog_livetune 1` to dial in
   from the console with no rebuild). *(GSC-only → linker-only rebuild.)*
3. **Wet ground:** bulk-swap the 90 `script_floor_ceiling` tokens to a verified
   wet stock material (e.g. `t7_concrete_floor_garage_cracked_wet_nw`); the 546
   `script_wall` tokens to a dark wall (e.g. `t7_concrete_bare_weathered_01`).
   No `.zone` edit.
4. **Reflection probes:** place ~6–8 `reflection_probe` entities (we have 0;
   shipped industrial map has 23) so neon mirrors in the wet ground. *(Baked → LED.)*
5. **One neon motif:** author 2–3 emissive "dead sign" materials and place the
   same few as landmarks.

**Effort:** 1–2 focused sessions.

### Phase 2 — per-zone skins + neon kit
Per-zone face retexture using the verified `t7_*` families (walls vs floors vs
glass per the table in §5); finish the reusable emissive neon kit (cyan/magenta/
amber) + place landmarks per zone; script a flicker pulse on a handful.
**Effort:** 3–5 sessions.

### Phase 3 — hero surfaces + optional custom sky/grade (defer until systems ship)
Rooftop skyline cutout; lab/PaP machine glow; **optional** cool custom
`vision/zm_abandoned_cyber_city.vision` grade; **optional** bespoke neon-night
HDRI skybox (only if `default_night` is judged insufficient — needs a CC0
PolyHaven HDRI + a `sky_latlong_hdr` material + sky xmodel + custom SSI + the
`xmodel,`/`material,`/`image,` `.zone` lines). Any CC0 pack runs the full custom
pipeline + a provenance note.

---

## 7. Sky & fog plan (ZM-safe, concrete)

**Sky (zero custom assets):** our `volume_sun` is already ZM-safe (all
`ssi*=default_day`). Change them — and worldspawn `skyboxmodel` — to
**`default_night`** / **`skybox_default_night`** (both verified present, both ZM-
safe). **Never** reintroduce `mp_havoc` / `ssi*_runtime_override=mp_havoc_overide`
→ hard link error `xmodel skybox_mp_havoc_override missing`. BSP-baked → full
pipeline (LED mandatory).

**Fog (script-only, implemented):** `_acc_atmosphere.gsc` → `SetVolFog(start,
halfway, halfwayHeight, baseHeight, r, g, b, maxOpacity)`. Defaults are a cold
low city haze; tune `halfway_dist` to the longest sightline so zombies/wallbuys
stay visible, cap `max_opacity` ≤ 0.8, bias RGB cool blue-cyan. GSC-only →
linker-only rebuild.

**Grade (optional, Phase 3):** custom cool `.vision` via `SetVisionSet`, or reuse
stock `zm_factory.vision`. Color-grade only; `rawfile,vision/...` `.zone` line if
custom. Linker-only.

---

## 8. Licensing policy (we publish to Steam Workshop)

The shipped `.ff` bundles the compiled textures, so anything we ship must be
legally redistributable.

- ✅ **Stock BO3 materials** — free, already in fastfiles. Default path.
- ✅ **Self-authored** art (our neon kit, skyline cutout, custom LUT/sky).
- ✅ **CC0 libraries** (Phase-3 fallback): **ambientCG**, **Poly Haven** (best for
  HDRI skies), **ShareTextures**, **Kenney** — all CC0, explicitly allow bundling
  raw files in a shipped game. Keep a provenance/credits note even though CC0
  needs none (takedown-defense).
- 🚫 **BLOCKER — never ship:** **textures.com / Poliigon** and **Quixel Megascans /
  Fab** — their terms forbid bundling raw assets in a third-party game mod.
  Reference/inspiration only. Likewise, **never lift textures baked into another
  community map** (e.g. `zm_alien_isolation`) — no reuse license.

---

## 9. Risks / traps (verified)

| Risk | Severity | Mitigation |
|---|---|---|
| MP-only sky reintroduced | high | only `default_night`/`default_black`/`skybox_zm_factory` or a custom ZM-safe sky; `grep` the `.map` for `havoc` after any sky edit |
| Reusing alien `black1_plaster`/`ayz_floor`/etc. as "stock" | high | they're custom + unlicensed; use verified `t7_*` names (§4) |
| Adding a `material,` `.zone` line per wall | high | wrong — face materials auto-resolve; only non-face assets (LUT/sky/FX/decal) get lines |
| Sky/probe/face change not relit | high | any BSP-baked change MUST go through `cod2map64` + LED before linker, or the look won't appear despite a clean link |
| Fog too thick hides zombies/wallbuys | medium | tune `halfway_dist` to longest sightline, cap opacity ≤0.8, lighter in hub/Vault/Lab |
| `surfaceType=error` on authored materials | medium | always set a real `surfaceType` (governs footstep + impact FX) |
| Linker builds stale deployed copy | high | `sync_to_modtools.ps1` + verify the deploy landed **before** every build |
| Non-power-of-2 / wrong-format custom image | medium | colorMap/normalMap = power-of-2 TIFF/PNG; HDR sky = `.exr`/`.hdr`, `semantic=HDR` |
| Custom GDT + source images outside the repo | medium | pick a repo home for any Phase-3 GDT + source `.tif`/`.exr`, pin `baseImage` paths |

---

## 10. Open design decisions (need owner input)

1. **Sky:** stock `default_night` (clean, zero-asset, star/moon dome) vs a bespoke
   smog-orange neon-night HDRI (Phase 3 cost). Is `default_night` enough for v1.0?
2. **Color grade:** keep `luts_t7_default`, switch to stock `zm_factory.vision`
   (free dark grade), or author a custom teal-crush `.vision` (Phase 3)?
3. **Fog tuning:** single global `SetVolFog`, or per-zone tuning (lighter hub/
   Vault/Lab)? Per-zone is more work, better mood/gameplay balance.
4. **Neon palette:** confirm cyan="live tech" / magenta="dead nightlife" /
   amber="dying power" so the emissive kit is authored once and reused.
5. **v1.0 art ceiling:** is Phase 1 the ceiling until systems ship, or do we do
   Phase 2 per-zone skins in this pass too?
6. **Credits file** for any CC0 use (recommended even though not required)?

---

## 11. Implementation status

| Item | State |
|---|---|
| Fog hook (`_acc_atmosphere.gsc`) | ✅ implemented, wired into `acc_main::init`, lint-clean, `.zone`-registered |
| Night sky (`default_night` SSI swap) | ⬜ Radiant edit (Phase 1.1) |
| Wet-ground re-skin (stock `t7_*`) | ⬜ Radiant edit (Phase 1.3) |
| Reflection probes | ⬜ Radiant edit (Phase 1.4) |
| Neon emissive kit | ⬜ APE authoring (Phase 1.5 / 2) |
| Per-zone skins | ⬜ Phase 2 |
| Custom sky / grade / skyline | ⬜ Phase 3 (deferred) |

Research dossier (full agent findings + sources) is in the workflow transcript;
verified facts are distilled here and in
[BO3_MAPMAKING_KB.md](BO3_MAPMAKING_KB.md).
