# 20 — Atmosphere & Materials (wall/floor skins, sky, fog, lighting)

> **Design + implementation reference for the map's *look*.** The map is fully
> built and painted — every face carries a real stock/custom material, the sky is
> a dimmed night SSI, volumetric fog + a per-zone baked light rig are live. This
> doc is now a LIVING REFERENCE: the shipped mechanism first, then the art
> direction it serves and the traps hit along the way. Pairs with the portable
> recipe in [BO3_MAPMAKING_KB.md](BO3_MAPMAKING_KB.md) (§ Materials, Sky & Fog).

**Status:** Phase-1 atmosphere (night sky · fog · wet-stock ground · per-zone baked
neon lights · reflection probes) is **SHIPPED**. The scene is lightmap-baked (LED
bakes again after the pre-stage3 revert — `-SkipLED` is a RED FLAG, not the
default). The colour grade ships **OFF** (base game colours) with dormant
live-swappable grades. Fog is ON by default. Code:
[_acc_atmosphere.gsc](../scripts/zm/zm_abandoned_cyber_city/_acc_atmosphere.gsc)
(fog/vision/ambient/FX) +
[_acc_perk_lights.gsc](../scripts/zm/zm_abandoned_cyber_city/_acc_perk_lights.gsc)/`.csc`
(power-on machine glow) + the `tools/gen_*_lights.js` / `tools/paint_*.js` /
`tools/apply_zone_materials.js` map generators.

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

**Lighting principle:** low-key noir. Ambient near-black (`volume_sun`
`global_fill_color "0 0 0"`); almost all illumination comes from **placed baked
neon light pools** (`tools/gen_neon_lights.js`) — pools of saturated colored light
separated by darkness. These are **power-gated** (`lightingstate1=0` → dark before
power, ignite when you flip the switch), so restoring power transforms the map.

**Sky / weather / fog:** night, no visible sun disc; thick low fog, cold blue-grey
near ground. Fog kills sightlines at short range — which also suits the small,
dense, shrunk-room layout.

---

## 2. Build-vs-buy stance (as shipped)

**~stock-skin first · a small custom GDT tier where it earns its keep · no bespoke
modeling.** Shipped analog verified: `zm_alien_isolation` is a full industrial
sci-fi map whose `archetypes` GDT is nearly empty — it ships almost entirely on
**stock materials skinned dark** plus a handful of APE-authored presets. We do the
same, with a couple of small custom-GDT pilots layered on (a dimmed night SSI, a
BO6 brick face material).

| Surface category | Stance | As shipped |
|---|---|---|
| **Walls / floors / ceilings** | **Stock-skin** | dark `t7_*` tokens painted onto the greybox face tokens; free, ship-safe, **no `.zone` line** (§3) |
| **Sky** | **Stock skybox + custom dimmed SSI** | `skybox_default_night` xmodel + custom `acc_ssi_night_dim80` SSI (§7) |
| **Fog** | **Script `SetVolFog`** | `_acc_atmosphere.gsc`, ON by default, live-tunable (§7) |
| **Neon** | **Baked colored light pools** | `gen_neon_lights.js` per-zone hues — replaced the planned emissive-material kit (§7c note) |
| **Grade** | **OFF (base colours)** | dormant `acc_grade_*` `.vision` files, live-swappable (§7b) |
| **Rooftop skyline backdrop** | not built | optional future (§12.5) |

---

## 3. How BO3 atmosphere actually works (verified)

Load-bearing technical facts — get them wrong and the build either fails or
silently ships stale. All file-verified against the install + `tmp/zm_alien_isolation`.

- **A brush face's material token *is* the GDT material name, and painting it just
  works.** In the `.map`, a face line ends with the material name. At link,
  `cod2map64` bakes that name into the BSP and the linker resolves it from any GDT
  in the Mod Tools project. **Re-skinning = swapping that token** (Radiant's
  material browser, or a bulk find/replace in the `.map` text via
  `tools/paint_*.js`). *Proven:* the map is fully painted with stock `t7_*` tokens,
  no greybox left, and it packs + renders clean (`tools/paint_walls.js` header).
- **Face materials need NO `.zone` line — and you must NOT add one for a stock
  face material.** Proof: shipped `zm_alien_isolation` `.zone` has **2** `material,`
  lines despite ~**1017** materials. A material referenced *by a brush face*
  auto-pulls from the GDT at cod2map/link time → no line. **TRAP:** adding a
  `material,<t7_name>` line makes the linker try to *compile* that material's
  techset from source (see §14) — the exact thing you're avoiding by leaving it
  face-only. Only assets referenced by **worldspawn / SSI / script / a model**
  (LUT, sky xmodel, HDR image, script decals, FX, `.vision` grades) need an
  explicit line.
- **Stock materials are free to ship** (already in installed fastfiles) — no GDT,
  no `.tif`, no `.zone` line, no redistribution concern. The hard part is the
  exact name; confirm in APE / Radiant's material browser.
- **Sky is not a brush material.** It's **(a)** worldspawn `skyboxmodel` (the
  inverted-sphere xmodel drawn at infinity) **+ (b)** the `volume_sun` entity's
  `ssi`/`ssi1`/`ssi2`/`ssi1_runtime_override` keys = *sun-set-info* asset names.
  An SSI holds its own skyboxmodel, sun color, exposure.
- **Fog is engine-side, separate from sky and vision.** `SetVolFog( startDist,
  halfwayDist, halfwayHeight, baseHeight, r, g, b, maxOpacity )` — 8-arg global,
  **0..1 float** RGB + opacity (stock `load_shared.gsc:807`). Driven from
  `_acc_atmosphere.gsc`.
- **A `.vision` file does color-grading ONLY** (tonemap / LUT-like curves) — it
  does **not** create fog. Applied via `VisionSetNaked`.
- **Build-step order matters.** World/material/sky/`volume_sun`/`skyboxmodel`/
  reflection-probe/**light-entity** changes are **BSP-baked** → full pipeline:
  `sync` → `cod2map64` → LED relight → `linker` (`tools/build_map.ps1`, LED by
  default). **Pure-script** fog (`SetVolFog`), a `.vision` rawfile, or the
  perk-light `.csc` FX = **linker-only** (`build_map.ps1 -GscOnly`). Painting a
  face token is BSP-baked (albedo the lightmapper sees changes) but is NOT a
  winding change, so it can't hit the `brush.cpp:1860` bake crash.

---

## 4. Stock asset shortlist (verified)

`verified` = byte-confirmed present in a GDT on this install / used by a shipped
map. Names actually painted into the map today are marked **(in use)**.

| Asset | Category | Status |
|---|---|---|
| `skybox_default_night` | sky xmodel (worldspawn `skyboxmodel`) | **verified · in use** — ZM-safe, no mp_havoc trap |
| `acc_ssi_night_dim80` | SSI (`volume_sun` ssi*) | **in use** — our custom dimmed-night SSI (`source_data/acc_ssi.gdt`) |
| `t7_asphalt_damaged_dark_wet` | ground/base — wet damaged asphalt | **verified · in use** (dominant surface) |
| `t7_metal_worn_iron_dark` | wall — dark worn iron | **in use** |
| `t7_concrete_wall_weathered_01_wet` | wall — weathered wet concrete | **in use** |
| `t7_zm_der_tile_hexagon` | hex tile (Lab + Paradise clean read) | **verified · in use** (Der Eisendrache hex) |
| `t7_metal_diamond_plate_worn_wet` | buyable-door slabs (distinct read) | **in use** (`tools/paint_doors.js`) |
| `t7_concrete_floor_garage_cracked_wet_nw` | floor — cracked wet concrete | **verified · in use** |
| `luts_t7_default` | current LUT (worldspawn `lutmaterial`) | **verified · in use** |
| `skybox_default_black` / `skybox_zm_factory` | alt dark sky xmodels | verified — starless/industrial fallbacks |

> ⚠️ **Do NOT reuse the `zm_alien_isolation` material vocabulary**
> (`black1_plaster`, `ayz_floor`, `really_dirty_emissive`, …). They live in that
> author's *custom* GDTs, are absent from our install, and carry no reuse license.
> Use `t7_*` names.

---

## 5. Per-zone art direction

Mood + material reference per zone (see [02_layout.md](02_layout.md) for the
gameplay graph). "Hero" = the 1–2 surfaces worth custom emissive/backdrop work.
Actual per-face materials are applied by `tools/apply_zone_materials.js` +
`tools/paint_region.js`; this table is the mood intent behind those picks.

| Zone | Mood | Walls / floors | Neon accent |
|---|---|---|---|
| **Plaza** | dead transit plaza, first breath of the ruin | grimed concrete + wet asphalt; cyber cable-panel wall accents | one dead **cyan** district sign |
| **Market** | drowned neon bazaar gone to rot | worn dirty brick + wet asphalt | densest zone — **magenta** dead stall signage |
| **Alley** | claustrophobic wet utility corridor | dirty black painted metal + wet asphalt | one failing **sodium/red** hazard light |
| **Bus Station** (hub) | lobby of a fallen tech megacorp | stainless steel panels + broken glass read | **cyan** corporate logo wall |
| **Vault** | cold sealed data-fortress | dirty-grey painted metal + metal grate floor | **cyan+amber** rack LEDs |
| **Helipad** | exposed to the dead sky | weathered concrete + wet asphalt pad | distant amber edge lights |
| **Lab / Paradise** | clandestine cyberware lab (+ the deep Paradise plaza) | clean **hex tile** (Der Eisendrache) + brushed steel | richest **live cyan+magenta** machine glows |

Fog is uniform globally (single `SetVolFog` authority); readability is managed by
the low fog base height, not per-zone fog volumes.

---

## 6. Phase-1 atmosphere — SHIPPED

Everything in Phase 1 is built. It is the ~85%-of-the-payoff-for-~15%-of-the-effort
core:

1. **Night sky:** worldspawn `skyboxmodel = skybox_default_night`; worldspawn +
   `volume_sun` all four `ssi*` = **`acc_ssi_night_dim80`** (custom dimmed SSI,
   `source_data/acc_ssi.gdt`; `wsi = default_night`). No `mp_havoc` anywhere.
   *(BSP-baked; `xmodel,skybox_default_night` is the only sky `.zone` line.)*
2. **Fog:** `_acc_atmosphere.gsc` → `SetVolFog` after blackscreen, cold blue-grey
   low haze, ON by default, every value live-tunable via `acc_fog_*` dvars (§7).
   Settles away on power-on. *(GSC-only → linker-only rebuild.)*
3. **Walls + floors + ceilings:** **all painted** — no greybox checker remains.
   The two greybox tokens (`script_wall` = 1152 wall faces, `script_floor_ceiling`
   = 1092 floor+ceiling faces, counted at the 2026-06-28 repaint) were bulk-swapped
   to stock `t7_*` via `tools/paint_walls.js`; per-region/per-zone refinement via
   `tools/paint_region.js` + `tools/apply_zone_materials.js` (Lab/Paradise hex
   tile, Plaza cable-panel walls, etc.); the **13 buyable zone doors** repainted to
   `t7_metal_diamond_plate_worn_wet` via `tools/paint_doors.js` so a door reads
   distinct from the wall (they had been the same asphalt/concrete tokens as the
   walls — which is why they vanished). Face tokens → **no `.zone` line**;
   LED-bake-clean; no missing-material warning.
4. **Reflection probes:** **15** `reflection_probe` entities placed (surface-only)
   so neon mirrors in the wet ground. *(Baked → LED.)*
5. **Baked neon light pools:** **157** light entities via `tools/gen_neon_lights.js`
   — one unique power-gated hue per zone (cyan/blue/magenta/red/orange/green/
   purple/yellow/white). This is the neon read; it replaced the originally-planned
   emissive-material kit (§7c note). *(Baked → LED.)*

---

## 7. Sky & fog (as shipped)

**Sky:** worldspawn `skyboxmodel = skybox_default_night`; worldspawn + `volume_sun`
all four `ssi*` = **`acc_ssi_night_dim80`**, our custom dimmed-night SSI in
`source_data/acc_ssi.gdt` (referenced 5× by the `.map`). This evolved from the
interim stock `default_night` SSI — the stock night read too bright for the low-key
noir target, so the SSI was cloned and dimmed. **Never** reintroduce `mp_havoc` /
`ssi*_runtime_override=mp_havoc_overide` → hard link error `xmodel
skybox_mp_havoc_override missing`. BSP-baked → full pipeline (LED mandatory).

**Fog (`_acc_atmosphere.gsc`, ON by default):** `apply_fog()` is the **single
`SetVolFog` authority** — no other code calls it, so nothing fights it. It waits on
the `initial_blackscreen_passed` flag (MANDATORY — fog can't be set before players
are in; this wait is literally how the haze gets set), then every 0.1s applies the
full haze or the settle/paradise override. Shipped defaults (the `#define`s):

```
start_dist 0 · halfway_dist 550 · halfway_height 750 · base_height 0
r 0.15 · g 0.19 · b 0.29 (cool blue-grey; MUST stay lighter than scene-black or
                          the fog is invisible) · max_opacity 0.80
```

Change-gated via `acc_set_vol_fog()` — it only calls the engine when a parameter
actually changed (the loop re-asserting identical values 10×/s buried
`console_mp.log` with "setVolFog: Old syntax used" spam, 2026-07-04).

**"City wakes up" — fog SETTLES AWAY on POWER-ON:** once the stock `power_on` flag
is set, `apply_fog` flips `level.acc_fog_cleared` and runs `settle_fog_step()` each
tick instead of the haze. That lowers the fog's **base height** (`SetVolFog`
`baseHeight`) one slight step **once per second**; because vol-fog opacity halves
every `halfway_height` units above the base, the dense layer sliding below the
floor thins the haze to nothing at eye level — it looks like fog settling into the
ground. Once the base has sunk `acc_fog_settle_depth` below the floor (invisible)
**or** `acc_fog_settle_max_steps` nudges have run, it's locked off with
`disable_fog()`. Gated by `acc_fog_clear_on_power` (default 1). With the dev
build's auto-power the haze is brief; in a switch-gated ship build it holds until
the player flips the switch.

**Paradise finale fog (user 2026-06-25):** the deep Paradise finale "rolls the fog
back in" — `paradise_fog_on()` sets `level.acc_paradise_fog`, which the single
`apply_fog` authority reads and then re-asserts the standard haze every tick,
overriding the power-on settle. Densest at the Paradise floor (z≈−1200, below the
haze base) so the whole sealed arena fogs in. `paradise_fog_off()` clears the flag
and hard-`disable_fog()`s for the victory cut.

> ⚠️ **HARD-WON: you cannot disable volumetric fog by zeroing opacity.**
> `SetVolFog(…, maxOpacity=0)` leaves the haze fully visible. Stock `_art.gsc:231`
> confirms it: `// couldn't find discreet fog disabling other than to never set it
> in the first place`. The ONLY reliable disable is to push the fog **start plane**
> out to ~100,000,000 units so fog begins beyond the world. `disable_fog()` does
> exactly that: `SetVolFog( 100000000, 100000001, 0,0,0,0,0,0 )`. This is why the
> power-on removal is a *downward sink* ending in `disable_fog()`, not an opacity
> ramp.

**Live-tune in-game (no rebuild):** the dev build launches with `+set developer 1`,
so open the console (`~`) and:
```
set acc_fog_on 0              // freeze/stop the re-apply loop
set acc_fog_halfway_dist 1000 // fog reaches half-density at this distance (lower = thicker)
set acc_fog_max_opacity 0.55  // 0..1 cap (lower = thinner; keep ≤ 0.8)
set acc_fog_r 0.15            // colour, 0..1 each (cool blue-grey)
set acc_fog_g 0.19
set acc_fog_b 0.29
set acc_fog_base_height 0
set acc_fog_halfway_height 750
set acc_fog_clear_on_power 0  // keep the haze for the whole match (no power-on removal)
set acc_fog_settle_step 200   // units the base sinks per nudge; smaller = slower/smoother
```
When the look is locked, bake the numbers into the `#define` defaults in
`_acc_atmosphere.gsc` (REQUIREMENTS.md "no silent tuning" rule) so they ship.

**Grade:** a global `VisionSetNaked` colour grade, applied at runtime with no
lightmap bake — but it ships **OFF** (base game colours). See §7b.

### 7b. Colour grade — OFF by default, dormant grades live-swappable

**Decision (user 2026-06-18):** every custom tint tested read *worse* than stock,
so the map ships **base game colours**: `ACC_VISION_ON = 0` in `_acc_atmosphere.gsc`
→ `apply_vision()` applies the stock neutral `"default"` vision and adds no tint.
The custom grades are NOT deleted — they stay zoned (`rawfile,vision/*.vision`) and
dormant, re-enable live:
```
set acc_vision_on 1                        // re-enable the custom grade (OFF by default)
set acc_vision_set acc_grade_magenta       // vibrant magenta / pink
set acc_vision_set acc_grade_orange        // amber-neon (warm)
set acc_vision_set acc_grade_dark          // deeper/darker magenta
set acc_vision_set default                 // stock neutral (== grade OFF)
set acc_vision_on 0                        // DEFAULT — grade off, base game colours
```
`apply_vision()` is change-gated (`want != applied`) so it does not spam the
renderer every tick. It also drives two special cases:
- **Power-on light warm-up** (`acc_power_light_ramp`, ~15s): the baked lights flip
  on instantly when power comes on (a binary lighting-state swap that can't be
  faded at the bake), so `apply_vision` holds a dark grade (`acc_grade_warm1`) then
  slow-lerps to `"default"` to fake a gentle swell — no flash, no dip-to-black.
  Warm-up stages: `acc_grade_blackout` (~5%) → `warm1` (~18%) → `warm2` (~45%) →
  `default`.
- **Abyss darkness** (`acc_abyss_dark_on`, default OFF): the deep trench's baseline
  brightness is the vision tonemap-curve top + sky/IBL ambient (surface-only
  probes → bright default cubemap), NOT the point lights — so dimming light
  intensity can't reach it. `acc_grade_abyss_dark` (`vkRM 0.08`, R=G=B, no hue)
  crushes that IBL/curve floor to black whenever a player is below the trench lip.
  Default OFF because the abyss darkness now comes from *fewer baked lights*
  (`gen_abyss_layer.js`); flip it on to also post-process-darken.

**`.vision` knob semantics (for authoring the `acc_grade_*` files):** `vkTT` =
white-point temp (6500 neutral, lower = cooler/bluer). `vkTS` = saturation (0 =
off; **the single biggest vibrancy lever**). `vkTC "r g b a"` = colour-filter
multiply + strength alpha (negative alpha DARKENS globally). `vkTO` = colour offset
(lift in blacks). `vkRGB0..4 @ vkL0..4` = the luminance→colour curve; per-stop
saturation = how far apart R/G/B are, brightness = the stop's magnitude. `vkRM` =
curve mix.

### 7c. The map-name `.vision` MUST stay neutral — "gray screen on revive"

**Symptom (user, testing):** after going DOWN and being REVIVED, the screen stays a
washed GRAY and the HUD reads "buggy" — but only after a death/revive, never on a
fresh spawn.

**Root cause (verified vs the stock mirror):** the engine's per-client visionset
manager uses the **map name** as each client's "default" visionset
(`visionset_mgr_shared.csc`). On REVIVE it **force-stamps
`VisionSetNaked(localClient, "zm_abandoned_cyber_city")` per client**
(`_zm_laststand.gsc`), which **bypasses our server-side global
`VisionSetNaked("default")`** — and `apply_vision()` is change-gated, so once
`applied == "default"` it never re-asserts and the engine's per-client grade wins.
Our old `vision/zm_abandoned_cyber_city.vision` was a desaturated cool grade → the
revive restore looked gray.

**Fix (shipped):** `vision/zm_abandoned_cyber_city.vision` is **byte-identical to
stock `default.vision`** (`vkRM 0.000000`, pure `R=G=B` ramp, `r_reviveFX_Enable
0`). Now the engine's per-client revive restore lands on neutral stock colours —
harmless by construction, coop-correct, and consistent with the "ship base colours"
decision in §7b. Linker-only (`.vision` is a rawfile). **RULE: never put a tint in
the map-name `.vision`.** A deliberate global grade goes through
`apply_vision`/`acc_vision_set` (the alternate `acc_grade_*` files) — NOT the
map-name file, which the engine force-restores per-client on every revive. (If a
distinct global grade is ever wanted, also add a force-reapply on the
`player_revived` edge so `apply_vision` re-wins the slot.)

### 7d. Perk machine + PaP glow on power-on — CLIENT-side FX

Base-zombies "machines light up when you restore power": dark before the switch,
coloured glow after. Implemented in
[_acc_perk_lights.gsc](../scripts/zm/zm_abandoned_cyber_city/_acc_perk_lights.gsc)
(server) + `.csc` (client).

> **THE KEY LESSON:** *server-side* `PlayFX`/`PlayFXOnTag` (from a `.gsc`) does NOT
> render in this build — that is why stock perk machines (server-side `perk_fx`,
> `_zm_perks.gsc:302`) are dark here. The path that DOES render is the **client
> VM**: stock power-ups glow via a clientfield + client-side `PlayFXOnTag`
> (`_zm_powerups.csc`). **Rule: to show an FX in this map, drive it from a `.csc`
> clientfield callback, not server `PlayFX`** — and the FX must be client-precached
> (`#precache("client_fx", …)`).

Mechanism: the server polls the `power_on` flag, then sets a per-perk colour-index
`accPerkGlow` clientfield on each `trigger.machine` + an invisible `script_model`
host at the PaP origin (the `pack_a_punch` ent is a *trigger*, not a model). The
`.csc` mirror registers the field + a leak-safe callback (`StopFX` old → store
`self.acc_glow_fx = PlayFXOnTag(...)`), replayed on the initial snapshot so late
joiners glow. Pure `.gsc/.csc/.zone/.fx` → `build_map.ps1 -GscOnly`, no Radiant
bake. `set acc_perk_lights_on 0` disables it.

**Per-perk colour:** only the *green* power-up aura ships and there's no runtime FX
tint, so per-perk colour = **one recoloured `.efx` clone per colour**.
`tools/gen_perk_glow_fx.js` remaps the tint triples + `dynamicLight2 _color` to
each hue and writes `<tools>\share\raw\fx\acc\light\fx_perk_glow_<colour>.efx`
(packed via `fx,acc/light/…` zone lines; **not in git — regenerate with the
tool**). The same glow `.efx` are reused by `_acc_atmosphere::apply_fx()` as
ambient neon sources. General rule: a faint or one-shot FX reads as "not lit" — use
the bright looping power-up aura as the glow base.

---

## 8. Licensing policy (we publish to Steam Workshop)

The shipped `.ff` bundles the compiled textures, so anything we ship must be
legally redistributable.

- ✅ **Stock BO3 materials** — free, already in fastfiles. Default path.
- ✅ **Self-authored** art (custom SSI, custom LUT/sky, recoloured glow `.efx`).
- ✅ **CC0 libraries**: **ambientCG**, **Poly Haven** (best for HDRI skies),
  **ShareTextures**, **Kenney** — all CC0, allow bundling raw files in a shipped
  game. Keep a `CREDITS.md` provenance note even though CC0 needs none.
- 🚫 **BLOCKER — never ship:** **textures.com / Poliigon** and **Quixel Megascans /
  Fab** (terms forbid bundling raw assets in a third-party mod). Likewise, **never
  lift textures baked into another community map** (e.g. `zm_alien_isolation`) — no
  reuse license.

---

## 9. Risks / traps (verified)

| Risk | Severity | Mitigation |
|---|---|---|
| MP-only sky reintroduced | high | only `default_night`/`default_black`/`skybox_zm_factory`/our `acc_ssi_night_dim80`; `grep` the `.map` for `havoc` after any sky edit |
| Reusing alien `black1_plaster`/`ayz_floor`/etc. as "stock" | high | custom + unlicensed; use `t7_*` names (§4) |
| Adding a `material,` `.zone` line for a stock face material | high | wrong — face materials auto-resolve; a line forces a techset compile that can fail (§14) |
| Sky/probe/face/light change not relit | high | any BSP-baked change MUST go through `cod2map64` + LED before linker (`build_map.ps1`, LED default) |
| `-SkipLED` used | high | RED FLAG — hides the `brush.cpp:1860` lightmapper regression; never the default |
| Server `PlayFX` from a `.gsc` | high | doesn't render — drive FX from a `.csc` clientfield (§7d) |
| Tint in the map-name `.vision` | high | force-restored per-client on revive = "gray screen on revive" (§7c); keep it stock-neutral |
| Fog too thick hides zombies/wallbuys | medium | tune `halfway_dist`, cap opacity ≤0.8 |
| Linker builds stale deployed copy | high | `sync_to_modtools.ps1` + verify the deploy landed **before** every build |

---

## 10. Decisions (as shipped)

| Decision | Choice |
|---|---|
| **Sky** | Stock `skybox_default_night` xmodel + **custom dimmed `acc_ssi_night_dim80` SSI** (dimmed from stock `default_night` for the low-key noir read). A bespoke HDRI sky remains an optional future upgrade (§12.3). |
| **Neon** | **Baked, power-gated per-zone coloured light pools** (`gen_neon_lights.js`) — replaced the planned emissive-material kit. Palette cyan/magenta/amber + per-zone hues. |
| **Materials** | Stock `t7_*` face tokens, no `.zone` lines. A couple of small custom-GDT face pilots layered in (BO6 brick). |
| **Colour grade** | **OFF — base game colours.** Dormant `acc_grade_*` files live-swappable (§7b). Never tint the map-name file (§7c). |
| **Fog** | Global `SetVolFog`, ON by default, single authority, settles away on power-on, re-asserted for the Paradise finale. |
| **Credits** | `CREDITS.md` provenance note for any CC0 asset (takedown-defense). |

---

## 11. Implementation status

| Item | State |
|---|---|
| Fog (`_acc_atmosphere.gsc`) | ✅ shipped — ON by default, single `SetVolFog` authority, power-on settle, Paradise re-fog, change-gated, live-tunable |
| Colour grade | ✅ shipped OFF (base colours); dormant `acc_grade_{magenta,orange,dark,abyss_dark,blackout,warm1,warm2}` + neutral map-name file, all zoned |
| Night sky | ✅ shipped — `skybox_default_night` + custom `acc_ssi_night_dim80` on all `ssi*` |
| Wall/floor/ceiling paint | ✅ shipped — fully painted stock `t7_*` (no greybox), per-zone via `apply_zone_materials.js`; buyable doors distinct via `paint_doors.js` |
| Reflection probes | ✅ 15 placed (surface-only), baked |
| Baked neon lights | ✅ 157 power-gated per-zone light entities (`gen_neon_lights.js`) |
| Perk/PaP power-on glow | ✅ client-side FX (`_acc_perk_lights.gsc/.csc`), per-perk recoloured `.efx` |
| Ambient dust/steam FX | ✅ `apply_fx()` (dust drift + steam vents; hero glow *sprites* removed — glow comes from baked lights) |
| Bespoke HDRI sky | ⬜ optional future (§12.3) |
| Rooftop skyline backdrop | ⬜ optional future (§12.5) |

---

## 12. Optional future kits

The Phase-1 core is shipped (§6/§11). These are the deferred, higher-effort art
upgrades — not blockers.

### 12.1 Per-zone material refinement (shipped tool)

`tools/apply_zone_materials.js` classifies each wall/floor face by position
(nearest zone center) and swaps in the zone's stock `t7_*` pick. Re-run it any time
to re-tune a zone (edit the `ZONES` table). All picks are byte-verified present.
Refine individual faces in Radiant / `tools/paint_region.js` for finer control.

### 12.2 (Superseded) Neon emissive-material kit → baked lights

The original plan was a small custom `acc_neon` GDT with three emissive "dead sign"
materials (cyan/magenta/amber). **This was superseded by baked coloured light
pools** (`gen_neon_lights.js`, §6/§7c) — a light entity casts the colored pool with
no visible on-map source, which reads better than a flat emissive plane on this
scene and needs no custom material-shader compile. If a bright *visible* neon
source is ever wanted, recess a glow `.efx` (§7d) just inside a wall/ceiling so
only its halo spills, rather than authoring emissive materials.

### 12.3 Bespoke HDRI night sky (optional, APE)

Replaces the current stock skybox + dimmed SSI if judged insufficient. Source a CC0
night-city equirectangular HDRI (Poly Haven), author `image` (`semantic=HDR`) →
`material` (`materialType=sky_latlong_hdr`) → inverted sky-sphere xmodel → custom
SSI, wire into worldspawn `skyboxmodel` + `volume_sun` `ssi*`, and add the
`xmodel,`/`material,`/`image,` `.zone` lines (NOT face-referenced, so required).
Never `mp_havoc`. Pin `baseImage` paths + a repo GDT home so a fresh machine
rebuilds.

### 12.4 Alternate `.vision` grades (shipped)

`acc_grade_{magenta,orange,dark}` (+ the neutral/warm/abyss utility grades) exist,
are zoned, and hot-swap live via `acc_vision_set` (§7b). Authoring more = drop a new
`vision/<name>.vision` + a `rawfile,vision/<name>.vision` zone line; linker-only.

### 12.5 Rooftop skyline backdrop (optional)

Cheap 2D/cutout far-tower silhouette with sparse dead-neon dots behind the Helipad —
fully original (no license risk), high atmosphere-per-effort. Not built.

---

## 13. Map-build state (reconciled)

**The map is fully built** — all seven surface zones (Plaza · Market · Alley · Bus
Station hub · Vault · Helipad · Lab) plus the vertical **Abyss Descent** underground
(L2/L3/L5 soul-box layers → the deep **Paradise** plaza) and the layered system
rooms (Exo Suit station, Armory upper room, Reactor, Glitch Altar, Jukebox, the
Transfer Vault / Exchange under the Plaza). Vault and Helipad — which were once
wired-but-shell-less zones — had their room shells injected (`tools/gen_rooms.js`)
and doorways cut in 2026-06-13, and have since been fully fleshed out along with
everything else.

**Historical note (kept for the technique, not the status):** those two rooms were
built as *fully closed 6-brush boxes* (floor, ceiling, 4 walls) first — guaranteed
leak-free, compiles clean — then the doorway gaps were cut directly in the `.map`
worldspawn aligned to the sliding door slabs, and the build validated through the
full pipeline (`cod2map64` navmesh from the `bin` cwd, LED, linker). "Closed box
first, cut doorways second" is the reliable order for adding a room to a baking map.
Underground/trench spawns and the below-zone abyss have their own gotchas — see
[docs/30](30_abyss_descent.md).

---

## 14. Painting materials — what works, and the one thing that doesn't

**Painting stock `t7_*` (and small custom-GDT) materials onto brush faces WORKS on
this install and is the shipped default.** The map is fully painted, packs clean,
and renders — proven live. A face's material token *is* the GDT material name
(§3); swapping the token (Radiant or `tools/paint_*.js`) re-skins the surface, the
material auto-pulls from the GDT at cod2map/link time, and **no `.zone` line is
needed or wanted**.

**The one thing that does NOT work: adding a `material,<name>` `.zone` line for a
face material.** Listing a material in the `.zone` makes the linker try to
*compile* that material's techset shaders from source — and the public-Steam tools
ship the compiled shader **cache** but historically not all of the shader
**source** (`failed to open source file: 'gbuffer_lit.hlsl' /
'techsetdef_buildshadowmap.hlsl'`). Face-referenced stock materials sidestep this
entirely because they resolve from the already-compiled fastfile cache. So:

- **Do:** paint the token, leave it out of the `.zone`. (This is why the `.zone`
  has a note that the painted `t7_*` walls/floors are intentionally NOT listed.)
- **Don't:** add a `material,` line for a wall/floor material, expecting it to
  "force the pack" — that's the code path that triggers the shader compile.

**Custom-authored face materials** (a new GDT material with its own images, e.g. the
BO6 brick pilot in `paint_plaza_walls.js`) are the higher-risk tier — they can still
trip the techset compile — but are usable on the current (post-2026-07-03) box with
the custom GDT installed. The safe, zero-risk default remains **stock `t7_*` face
tokens, no `.zone` line**.

> The earlier conclusion that *all* material painting was permanently blocked
> (2026-06-13) was wrong: it conflated "you can't `.zone`-list a face material"
> (true) with "you can't paint one" (false). The 2026-06-28/29 repaint proved stock
> face-token painting ships clean.

---

## 15. Soundscape (audio) — see [docs/23](23_sound_plan.md)

This doc owns the map's *look*; **audio has its own spec in
[23 — Sound & Music Plan](23_sound_plan.md)**. Short version so the atmosphere
picture is complete:

- `_acc_atmosphere.gsc` owns the audio half too: a one-shot main theme
  (`acc_main_theme`, played after the blackscreen), an optional 2D looping ambient
  city bed (`acc_amb_city_bed`, `set acc_amb_on 1`), and it kills stock zombies
  music at init so our theme has no gap. Music routes through the single
  `_acc_music` channel so a boss/jukebox track cleanly takes over.
- The neon palette maps to sound — cyan = live-tech hums/beeps, magenta =
  dead-nightlife muffle, amber = dying-power buzz.
- **Reverb is BSP-driven** (Radiant `ambient_room` volumes → stock presets via
  `ambient_mod.csv`), so a per-zone reverb pass is a full `cod2map64`+LED+linker
  build — same constraint as a sky/probe edit (§3, §9).
- **Licensing is identical to §8:** stock / self-authored / **CC0 only**.

---

Verified against code 2026-07-10 (`_acc_atmosphere.gsc`, `_acc_perk_lights.gsc/.csc`,
`map_source/zm/zm_abandoned_cyber_city.map`, `zone_source/…`, `source_data/acc_ssi.gdt`,
`tools/paint_*.js` / `gen_*_lights.js` / `apply_zone_materials.js`, `vision/`).
