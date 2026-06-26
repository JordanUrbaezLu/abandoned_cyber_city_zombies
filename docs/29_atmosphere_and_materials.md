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
| **Plaza** | dead transit plaza, first breath of the ruin | grimed concrete + cracked wet pavement | one dead **cyan** district sign; sodium bulkheads | partial (open) | flickering cyan welcome-sign archway; puddle field + reflection probes |
| **Market** | drowned neon bazaar gone to rot | corrugated metal + plaster, heavy rust; wet tile | densest zone — **magenta** dead stall signage | mostly enclosed | wall of stacked dead magenta ad boards; sparking-cable tangle |
| **Alley** | claustrophobic wet utility corridor | dirty metal ducting + pipes; wet concrete runoff | minimal — one failing sodium light + red hazard panel | none | dripping-pipe + steam-vent run w/ single sodium cone |
| **Bus Station** (hub) | lobby of a fallen tech megacorp | ruined polished stone/metal + broken glass curtain wall; dark polished tile | **cyan** corporate logo wall, half-flickering | partial (broken skylight) | giant backlit corp logo over dead fountain; live cyan hack-terminal screen |
| **Vault** | cold sealed data-fortress | blue-grey server racks + metal panels; dark grating | sea of tiny **cyan+amber** rack LEDs | none (underground) | server-rack corridor w/ thousands of blinking LEDs; Overload core column (amber pulse) |
| **Helipad** | exposed to the dead sky, ruined skyline | wet helipad concrete + faded "H"; low AC units | distant dark skyline + amber edge lights | **maximum** — the sky-reveal payoff | ruined-city skyline backdrop (custom cutout); derelict helicopter wreck |
| **Lab** | clandestine cyberware lab, tech still hums | clean-gone-grimy panels + conduit; tech floor w/ under-glow | richest **live cyan+magenta** machine glows (justified — upgrade hub) | none (deepest) | PaP/Overclock terminal cluster glow; Signal Staff craft centerpiece |

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

**"City wakes up" removal (on POWER-ON — settles away, updated 2026-06-18):** the haze
comes in once the intro blackscreen passes (the `initial_blackscreen_passed` flag — this
is why it appears ~5s in alongside the round-start text; a global render state / 2D
sound can't reach players before that — and this wait is MANDATORY, it's how the fog
gets set at all), then **when power is turned on it SETTLES AWAY DOWNWARD** rather than
vanishing instantly. Mechanism: `apply_fog` is the single `SetVolFog` authority; it
applies the full haze each 0.1s tick and **polls the stock `power_on` flag** (exists-
guarded). Once power is on it flips `level.acc_fog_cleared` and runs `settle_fog_step()`
each tick. That lowers the fog's **base height** (the `SetVolFog` `baseHeight` arg — where
the haze is densest) a slight step **once per second**; because vol-fog opacity halves
every `acc_fog_halfway_height` units above the base, the dense layer sliding below the
floor thins the haze to nothing at eye level — it looks like fog settling into the
ground. Once the base has sunk `acc_fog_settle_depth` below the floor (invisible) **or**
`acc_fog_settle_max_steps` nudges have run, it's locked off for good with `disable_fog()`
(opacity still can't be faded directly — see the warning below — so the *sink* IS the
fade). Gated by `acc_fog_clear_on_power` (default 1). **Timing note:** with the dev
build's hardcoded auto-power (`acc_auto_power 1`, ~1.5s after blackscreen) the haze is
brief; in a switch-gated ship build (`acc_auto_power 0`) it holds until the player
flips the power switch. Live knobs:
```
set acc_fog_clear_on_power 0   // keep the haze for the whole match (no auto-removal)
set acc_fog_settle_interval 1  // seconds between each downward nudge (default 1s)
set acc_fog_settle_step 200    // units the base sinks per nudge; smaller = slower/smoother
set acc_fog_settle_depth 7500  // how far down = invisible (then hard-disabled)
set acc_fog_settle_max_steps 1200 // safety cap on nudges, then locked off
set acc_fog_on 0               // freeze the current look (stops re-apply)
```

> ⚠️ **HARD-WON: you cannot disable volumetric fog by zeroing opacity.** `SetVolFog(
> …, maxOpacity=0)` leaves the haze fully visible. Stock `_art.gsc:231` confirms it
> verbatim: `setExpFog( 100000000, 100000001, 0, 0, 0, 0 ); // couldn't find discreet
> fog disabling other than to never set it in the first place`. The ONLY reliable
> disable is to push the fog **start plane** out to ~100,000,000 units so fog begins
> beyond the world. `disable_fog()` does exactly that:
> `SetVolFog( 100000000, 100000001, 0,0,0,0,0,0 )`. Every earlier fog-clear attempt
> (power-on lift, opacity-fade-on-first-kill) failed for this reason — not the death
> callback (it fired fine), the opacity lever itself.

**Live-tune in-game (no rebuild):** the dev build launches with `+set developer 1`,
so press **`~`** (tilde, top-left of the keyboard) for the console, then:
```
set acc_fog_livetune 1        // turn ON live re-apply (re-applies every 0.5s)
set acc_fog_halfway_dist 1000 // fog reaches half-density at this distance (lower = thicker)
set acc_fog_max_opacity 0.55  // 0..1 cap (lower = thinner; keep ≤ 0.8)
set acc_fog_r 0.02            // colour, 0..1 each (cool blue-cyan)
set acc_fog_g 0.03
set acc_fog_b 0.06
set acc_fog_start_dist 0      // distance where fog begins
set acc_fog_halfway_height 600
set acc_fog_base_height 0
set acc_fog_livetune 0        // freeze at the current look when happy
```
When the look is locked, bake the final numbers into the `#define` defaults in
`_acc_atmosphere.gsc` (REQUIREMENTS.md "no silent tuning" rule) so they ship.

**Grade (the colour-grade IS the atmosphere lever here — implemented):** a custom
`.vision` applied globally via `VisionSetNaked` (not the optional polish it was
planned as — with LED dead and materials blocked, the grade carries the ENTIRE
look). `rawfile,vision/...` `.zone` line per file. Linker-only + live-swappable
(`set acc_vision_set <name>`). See §7b.

### 7b. Dark + vibrant grade (investigation + shipped fix, 2026-06-17)

**Symptom:** map read dull / washed light-grey ("white"). **6-probe investigation
root cause, ranked:**
1. **The grade itself.** `vision/zm_abandoned_cyber_city.vision` had `vkTS 0`
   (saturation OFF) and a 5-stop luminance→colour curve where every stop was a
   near-equal `R≈G≈B` blue-grey, at `vkRM 0.8` — a hard DESATURATE + BRIGHTEN.
2. **Fullbright base.** LED bake is permanently dead (`brush.cpp:1860` crash on
   enclosed geometry); zero placed lights; `volume_sun global_fill_color "0 0 0"`.
   So every surface sits at the TOP of the curve → the brightest/greyest stop
   (old `vkRGB4 0.69/0.72/0.80`) → washed light blue-grey. Darkening the curve top
   is therefore MANDATORY, not optional.
3. **Flat greybox materials** (660 `script_wall` + 366 `script_floor_ceiling`,
   `lightmap_gray`, no colour/emissive). Reskin BLOCKED (§14).
4. `vkTC` near-neutral, no cyber cast.

**`.vision` knob semantics:** `vkTT` = white-point temp (6500 neutral, lower =
cooler/bluer). `vkTS` = saturation (0 = off; **the single biggest vibrancy lever**).
`vkTC "r g b a"` = colour-filter multiply + strength alpha (negative alpha globally
DARKENS — stock `zod_ritual_dim` uses ~ -1.3). `vkTO` = colour offset (lift in
blacks). `vkRGB0..4 @ vkL0..4` = the luminance→colour curve; **per-stop saturation =
how far apart R/G/B are**, brightness = the stop's magnitude. `vkRM` = curve mix.

**Grade history — every tint tested worse than stock; grade now OFF by default
(user, 2026-06-18):** passes went dark-teal (`vkTS 0.70`) → aggressive magenta
(`vkTS 0.90`, `vkRM 1.0`) → light-cyan restore → near-neutral curve with a faint cyan
bias (`R = 0.96·G`). The user judged each one to make the map look worse and asked to
**remove all tint and ship BASE GAME COLOURS.** So the grade is now **OFF by default**:
`ACC_VISION_ON = 0` in `_acc_atmosphere.gsc` → `apply_vision` applies the stock neutral
`"default"` vision and adds no tint. **Key lesson stands:** on a flat fullbright scene a
grade can only flatly tint a uniform field — it can't add contrast — so any custom hue
tends to read as a muddy wash; stock-neutral is the honest baseline until real SCENE
contrast exists (emissive props + placed colour FX). The custom grades are NOT deleted —
they stay zoned and dormant, re-enable live with `set acc_vision_on 1`:
```
set acc_vision_on 1                        // re-enable the custom grade (OFF by default)
set acc_vision_set zm_abandoned_cyber_city // == stock neutral (the map-name file is now stock default, see §7c)
set acc_vision_set acc_grade_magenta       // vibrant magenta / pink (vkTS 0.98)
set acc_vision_set acc_grade_orange        // amber-neon (warm vkTT 7400)
set acc_vision_set acc_grade_dark          // deeper/darker magenta
set acc_vision_set default                 // stock neutral (== grade OFF)
set acc_vision_on 0                        // DEFAULT — grade off, base game colours
```
**Ceiling reached here:** a grade can only saturate a flat field — it cannot create
contrast. If even bold magenta reads dull, that's the fullbright-flat scene talking,
and the real neon punch needs SCENE contrast (emissive prop xmodels + placed colour
FX, below), not more grade tuning.

### 7c. The map-name `.vision` MUST stay neutral — "gray screen on revive" (2026-06-24)

**Symptom (user, testing):** after going DOWN and being REVIVED, the screen stays a washed
GRAY, the crosshair damage numbers seem to vanish (washed out under the gray), and the HUD
reads "buggy" — but only after a death/revive, never on a fresh spawn.

**Root cause (verified vs the stock mirror, multi-agent audit):** the engine's per-client
visionset manager uses the **map name** as each client's "default" visionset
(`visionset_mgr_shared.csc:225` → `"zm_abandoned_cyber_city"`). On a DOWN it activates the
per-client laststand/death visionsets; on REVIVE it deactivates them and **force-stamps
`VisionSetNaked(localClient, "zm_abandoned_cyber_city")` per client** (`_zm_laststand.gsc`,
`visionset_mgr_shared.csc:1007`). That per-client restore **bypasses our server-side global
`VisionSetNaked("default")`** — and our `apply_vision()` is **change-gated** (it only re-fires
when `want != applied`, `_acc_atmosphere.gsc`), so once `applied == "default"` the loop never
re-asserts and the engine's per-client grade wins. Our shipped
`vision/zm_abandoned_cyber_city.vision` was a **desaturated cool grade** (`vkRM 1.0`, ramp
`0.24/0.25/0.25`) — so the revive restore looked gray. The damage numbers were never unbound
(the LUI overlay/feed/watchers all survive revive — per-controller models, no `CloseLUIMenu`
anywhere); they just lost contrast under the wash.

**Fix (shipped):** make `vision/zm_abandoned_cyber_city.vision` **byte-identical to stock
`default.vision`** (`vkRM 0.000000`, pure `R=G=B` ramp, `r_reviveFX_Enable 0`). Now the
engine's per-client revive restore lands on **neutral stock colours** — harmless by
construction, coop-correct, zero GSC, and consistent with the "ship base colours" decision in
§7b (the map-name grade was a vestige that contradicted it and only ever surfaced on revive).
Linker-only (`.vision` is a rawfile — no LED bake). **RULE: never put a tint in the map-name
`.vision`.** A custom global grade goes through `apply_vision`/`acc_vision_set` (the alternate
`acc_grade_*` files) — NOT the map-name file, which the engine will force back per-client on
every revive regardless of the server slot. (If a deliberately distinct global grade is ever
wanted, also add a force-reapply escape so `apply_vision` re-wins the slot on a `player_revived`
edge — but with the map-name file neutral that is unnecessary.)

**Lever plan for MORE colour (highest impact-per-effort first):** ① the grade above
(done — linker-only, live). ② alternate/per-zone `.vision` swaps (GSC-only). ③
placed colour FX emitters at signage/machines (geometry rebuild, NOT LED; verify
`.efx` on disk first — script `PlayFX` is unreliable in this build, place as Radiant
emitters). ④ cooler worldspawn LUT swap (`luts_t7_default` → cooler stock LUT;
cod2map64, no LED). ⑤ stock EMISSIVE PROP xmodels — their glow materials ship with
the model, bypassing the blocked face-material shader compile (geometry rebuild).
**AVOID:** baked light entities / LED relight (permanently dead), brush-face material
reskin (§14). The grade + emissive props is the whole viable path to dark+vibrant.

### 7c. Perk machine + PaP glow on power-on — CLIENT-side FX (implemented 2026-06-18)

Base-zombies "machines light up when you restore power": dark before the Bus Station
switch, coloured glow after. Implemented in `_acc_perk_lights.gsc` (server) + `.csc`
(client). **THE KEY LESSON (root-caused via a multi-agent workflow):** *server-side*
`PlayFX`/`PlayFXOnTag` (from a `.gsc`) does NOT render in this build — that is why the
2026-06-17 attempt failed, why `_acc_lockdown`'s server glow is invisible, and why stock
perk machines (server-side `perk_fx`, `_zm_perks.gsc:302`) are dark here. The path that
DOES render is the **client VM**: stock power-ups glow via a `scriptmover` clientfield +
client-side `PlayFXOnTag` (`_zm_powerups.csc`), and power-ups render fine. So the rule is:
**to show an FX in this map, drive it from a `.csc` clientfield callback, not server
`PlayFX`** — and the FX must be client-precached (`#precache("client_fx", …)`), which the
2026-06-17 server-only attempt was missing.

Mechanism: server polls the `power_on` flag (copying `_acc_atmosphere::apply_fog`), then
sets a per-perk colour-index `accPerkGlow` clientfield on each `trigger.machine`
(`GetEntArray("zombie_vending","targetname")`) + an invisible `script_model` host spawned
at the PaP origin (the `pack_a_punch` ent is a *trigger*, not a model). The `.csc` mirror
registers the field + a leak-safe callback (`waittill_dobj` → `StopFX` old → store
`self.acc_glow_fx = PlayFXOnTag(...)`), replays on the initial snapshot so late joiners
glow. **LED-safe: pure `.gsc/.csc/.zone/.fx`, no `.map` edit → `build_map.ps1 -GscOnly`,
never touches the Radiant bake.** `set acc_perk_lights_on 0` disables it.

**Per-perk colour (validated in-game 2026-06-18):** only the *green* power-up aura
(`zombie/fx_powerup_on_green_zmb`) ships and there is no runtime FX tint, so per-perk colour =
**one recoloured `.efx` clone per colour**. The green is pure `colorGraph` tint on white glow
sprites (no green texture), so `tools/gen_perk_glow_fx.js` remaps the three tint triples
(`0.25098 1 0.25098`, `0.501961 1 0.501961`, `0 0.458824 0`) + the `dynamicLight2 _color` to
each target hue, preserving the brightness/alpha curves, and writes
`<tools>\share\raw\fx\acc\light\fx_perk_glow_<colour>.efx` (packed via the `fx,acc/light/…`
zone lines; **not in git — regenerate with the tool**, like the external asset packs). Colours:
Jugg red, Speed Cola green, Double Tap yellow, Stamin-Up orange, Mule Kick amber, Quick Revive
blue, Deadshot white, Widow's Wine purple, Electric Cherry/PhD cyan, PaP gold. To retune, edit
the `COLORS` weights in the generator + rebuild (`-GscOnly`). General rule reaffirmed: a faint
or one-shot FX reads as "not lit" — use the bright looping power-up aura as the glow base.

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

## 10. Decisions (locked 2026-06-13)

| Decision | Choice |
|---|---|
| **Sky** | **Bespoke smog-orange neon-night HDRI** (Phase 3 target). Interim: stock `default_night` is set in the `.map` now so the map builds to night immediately; swap to the custom sky once its APE assets exist (build kit in §12.3). |
| **Art scope** | **Full send** — Phases 1+2+3 (night/fog/wet ground → per-zone skins → hero surfaces + custom sky/grade). Not time-boxed to Phase 1. |
| **Neon palette** | **Cyan / magenta / amber.** Cyan = live tech (screens, PaP, healthy signage); magenta = dead nightlife (market); amber = dying/emergency power. Emissive kit authored once, reused (§12.2). |
| **.map work** | **I do the plain-text flip** (sky keys + global wall/floor swap, done); per-face/per-zone paint + APE authoring are on the Windows box (Radiant/APE). |
| **Color grade** | Custom cool/teal-crush `.vision` in Phase 3 (§12.4). Interim `luts_t7_default`. |
| **Fog** | Global `SetVolFog` first; per-zone tuning later if needed (lighter hub/Vault/Lab). |
| **Credits file** | Yes — keep a `CREDITS.md` provenance note for any CC0 asset (takedown-defense), even though CC0 needs none. |

---

## 11. Implementation status

| Item | State |
|---|---|
| Fog hook (`_acc_atmosphere.gsc`) | ✅ implemented, wired into `acc_main::init`, lint-clean, `.zone`-registered |
| Night sky (`default_night` interim) | ✅ set in `.map` worldspawn + `volume_sun` (skyboxmodel `skybox_default_night`, all `ssi*=default_night`); **needs a full build** (cod2map64+LED+linker) to render |
| Global wall skin (`t7_concrete_bare_weathered_01_dark`) | ✅ all 546 wall faces in `.map`; needs build |
| Global wet floor (`t7_concrete_floor_garage_cracked_wet_nw`) | ✅ all 90 floor faces in `.map`; needs build |
| Reflection probes | ✅ 7 placed in `.map` (one per zone center, z≈90, named `acc_probe_*`); **grow the box to each zone's extent + retune brightness in Radiant** once visible. Baked → needs the LED pass |
| Per-zone skins | ✅ 5 built zones via `tools/apply_zone_materials.js` (spawn=concrete, market=brick, alley=black-metal, corp=steel, lab=brushed-steel); ⬜ **vault + roof have no built wall geometry yet** (see §13) |
| Neon emissive kit | ⬜ APE authoring, spec'd in §12.2 (Phase 2) |
| Bespoke HDRI sky | ⬜ APE authoring, build kit in §12.3 (Phase 3) |
| Custom `.vision` grade | ⬜ §12.4 (Phase 3) |
| Rooftop skyline backdrop | ⬜ §12.5 (Phase 3) |

> **To see the flip:** sync → `cod2map64` → `radiant_modtools -ledSilent +recompute`
> (LED relight is mandatory) → `linker`. The fog (script-only) would rebuild with
> linker alone, but the sky + material changes are BSP-baked and need the full pass.

---

## 12. Build kits (full-send, locked decisions)

Concrete, do-this specs for the parts that need the Windows box (Radiant face-paint
+ APE asset authoring). Names marked `confirm-in-APE` — verify the exact token in
the material browser before painting (a typo ships a checkerboard).

### 12.1 Per-zone material map (Phase 2)

✅ **Applied** via `tools/apply_zone_materials.js` — a one-shot that classifies each
wall/floor face by its own position (nearest zone center) and swaps the global
concrete for the zone's byte-verified `t7_*` material. Re-run it any time (e.g.
after Vault/Roof rooms are built, or to change a zone's pick — edit the `ZONES`
table in the tool). Materials actually applied (all byte-verified present):
spawn = dark concrete; market = `t7_brick_worn_dirty_red_wet`; alley =
`t7_metal_painted_wall_dirty_black` + `t7_asphalt_damaged_dark_wet_nw`; corp =
`t7_metal_panel_2x1_stainless_steel_matte`; vault = `t7_metal_painted_wall_dirty_grey`
+ `t7_metal_grate_flooring`; roof = `t7_concrete_bare_weathered_01` +
`t7_asphalt_damaged_dark_wet`; lab = `t7_metal_panel_2x1_stainless_steel_brushed`
+ `t7_metal_floor_lab_panels`. (Vault/Roof are wired but have no geometry — see §13.)
Refine individual faces in Radiant for finer control. The table below is the
original mood reference.

| Zone | Walls | Floor | Accent |
|---|---|---|---|
| Plaza | `t7_concrete_bare_weathered_01_dark` (base) | `t7_concrete_floor_garage_cracked_wet_nw` | — |
| Market | `t7_metal_corrugated_rust` *(confirm)* + `t7_concrete_poured_bunker_dirty_01_wet` | `t7_concrete_bare_dark_01_wet` + debris | rust streaks (`t7_decal_grunge` confirm) |
| Alley | `t7_metal_duct_insulation_01_grey` | `t7_asphalt_damaged_dark_wet` | pipe/duct props |
| Bus Station (hub) | `t7_glass_dirty_streaks_cracked` *(confirm)* + `t7_concrete_poured_bunker_dirty_01` | `t7_concrete_floor_garage_cracked_wet_nw` (polished read) | broken curtain wall |
| Vault | `t7_metal_duct_insulation_01_grey` (rack read) | dark grating *(confirm `t7_metal_*grate*`)* | rack-LED emissive (§12.2) |
| Helipad | `t7_concrete_bare_weathered_01` | `t7_asphalt_damaged_dark_wet` (wet pad) | faded "H" decal |
| Lab | `t7_concrete_bare_weathered_01_dark` + panel *(confirm `t7_metal_panel_*`)* | `t7_concrete_floor_garage_cracked_wet_nw` | machine emissive glow |

### 12.2 Neon emissive kit (Phase 2, APE) — cyan / magenta / amber

Author ONE small GDT `acc_neon` (save in `<tools>\source_data`), three emissive
"dead sign" materials, reused as landmarks (not per-zone bespoke):

| Material | Color (emissive) | Use |
|---|---|---|
| `mtl_acc_neon_cyan` | `#19E0FF` | live tech — Corp logo, hack screen, Lab/PaP machines, Plaza district sign |
| `mtl_acc_neon_magenta` | `#FF2E88` | dead nightlife — Market stall signs/ad boards |
| `mtl_acc_neon_amber` | `#FF8A1E` | dying power — Alley hazard panel, Vault rack LEDs + Overload core, bulkheads |

Neon RGB (0–1, for `colorTint`): cyan `0.10 0.88 1.00` · magenta `1.00 0.18 0.53`
· amber `1.00 0.54 0.12`.

**Copy-paste APE recipe** (the reliable path = duplicate a shipped emissive, not
hand-author the ~300-field GDT). Shipped emissive examples to clone:
`door_light_emissive` / `main_light_emissive` / `posters_light_lightstrip_emissive`
(verified in `tmp/zm_alien_isolation/texture_assets/alien_isolation_textures.gdt`).

1. **Source images** (you make these — APE can't): one **256×256 TIFF** per color.
   Simplest = a solid bright neon fill (the colorTint does the work); nicer = a
   sign/grime glyph. Power-of-2, TIFF. Drop them in
   `<tools>\texture_assets\acc_neon\` (e.g. `acc_neon_cyan.tif`). CC0 sign sprites:
   Kenney / itch.io (see CREDITS.md). Keep an unlit copy too if you want flicker.
2. **GDT:** APE → File → New GDT → save as `acc_neon.gdt` **in `<tools>\source_data`**
   (outside source_data it won't load).
3. **Material (×3):** Asset → New → type `material` → GDT `acc_neon` → name
   `mtl_acc_neon_cyan` (then `_magenta`, `_amber`). Easiest: open a stock/shipped
   **emissive** material, **Save As** into `acc_neon` under the new name, so the
   emissive/HDR fields carry over. Then set:
   - `colorMap` → your `acc_neon_<color>.tif` (the button auto-creates the image
     asset; set its semantic = diffuseMap).
   - `colorTint` → the neon RGB above (this is what makes it read as that color).
   - `surfaceType` → a real value (`plastic`/`glass`) — **never `error`**.
   - keep the template's emissive/self-illum + HDR-scale fields (that's the glow);
     bump the HDR/emissive scale up for a brighter sign.
4. **Build the GDT:** Save All → run `gdtdb.exe /update` (or it updates on save).
5. **Apply:** in Radiant's material browser, filter `mtl_acc_neon_`, paint onto the
   sign/screen faces (or thin decal brushes) at each landmark. **Face token →
   no `.zone` line** (auto-pulled, like all face materials).
6. **Source images ship inside the `.ff`** → keep them CC0/original (CREDITS.md).
   Decide a repo home for `acc_neon.gdt` + the `.tif`s so a fresh machine rebuilds
   (docs/29 §9).

**Flicker (optional, later):** the "dead signage" stutter is a small GSC follow-up
— pulse a light entity / swap the lit↔unlit material on a timer; can extend
`_acc_atmosphere.gsc`. Not needed for a static neon read.

### 12.3 Bespoke smog-orange HDRI sky (Phase 3, APE) — the locked sky target

Replaces the interim `default_night`. Steps:
1. **Source** a CC0 **night-city** equirectangular HDRI from **Poly Haven**
   (e.g. a "dikhololo_night" / urban-night / "moonless_golf"-style dark sky;
   pick one with a low warm horizon glow for the smog-orange read). CC0 → ship-safe.
   Keep it `.exr`/`.hdr`, equirectangular (convert a cubemap to panorama first).
2. **Image asset** (`image.gdf`): `baseImage` = the `.exr`, `semantic = HDR`,
   `coreSemantic = HDR`.
3. **Sky material** (`material.gdf`): `materialType = sky_latlong_hdr`,
   `materialCategory = Geometry`, `colorMap` = that HDR image. Name `mtl_acc_sky_citynight`.
4. **Sky xmodel**: an inverted sky-sphere with that material at LOD0. Name
   `acc_skybox_citynight` (duplicate/retarget a stock sky sphere).
5. **SSI** (`ssi.gdf`): `acc_ssi_citynight`, `skyboxmodel = acc_skybox_citynight`,
   cool low sun color, low `ev/stops`, `enablesun = 1`.
6. **Wire** in the `.map`: worldspawn `skyboxmodel` → `acc_skybox_citynight`;
   `volume_sun` `ssi*` → `acc_ssi_citynight`. **Never** `mp_havoc`.
7. **`.zone` lines** (NOT face-referenced, so required):
   `xmodel,acc_skybox_citynight` + `material,mtl_acc_sky_citynight` + `image,<hdr_image>`.
8. Decide a repo home for `acc_neon`/`acc_sky` GDT + source `.exr`/`.tif` and pin
   `baseImage` paths, or a fresh machine can't rebuild (see §9 risks).

### 12.4 Cool color grade (Phase 3)

Author `rawfile,vision/zm_abandoned_cyber_city.vision` — cool color temp, blue/cyan
grade nodes, slight desaturation. Apply via `SetVisionSet` at level start. Add the
`rawfile,vision/...` `.zone` line. Linker-only rebuild. (Interim: `luts_t7_default`,
or reuse stock `zm_factory.vision` for a free dark grade.)

### 12.5 Rooftop skyline backdrop (Phase 3)

Cheap 2D/cutout far-tower silhouette with sparse dead-neon dots behind the Helipad —
fully original (no license risk), high atmosphere-per-effort, sells the "whole dead
city" establishing read.

---

## 13. Map-state finding: 2 of 7 zones have no built room geometry

Discovered while applying the per-zone material pass (§12.1). The map's **636
wall/floor faces** classify by position into only **5 zones** — the per-zone pass
skinned: spawn (342 wall / 51 floor), corp (71/14), alley (50/9), market (42/8),
lab (41/8). **Vault and Roof got 0 faces** — their region (vault ≈ x1719 y2800,
roof ≈ x-1719 y2740) contains no wall/floor brushes at all. The built greybox is a
central spine **Plaza → Corp → Lab** plus **Market** (west) and **Alley** (east);
the **Vault and Helipad rooms are not built** — they exist only as
`info_volume` gameplay zones + spawner structs + door/feature entities, with no
walls or floor.

**Implications:**
- Atmosphere can only skin what exists. Vault/Roof will pick up materials (and
  their §12.1 picks: vault = dirty-grey metal + grate floor; roof = weathered
  concrete + wet asphalt) **automatically the next time `tools/apply_zone_materials.js`
  runs**, but only **after** their rooms are built in Radiant.
- This is a **map-construction gap**, not just an art gap — those two zones aren't
  playable spaces yet despite being wired into the zone graph + spawn logic. Worth
  reconciling against the "full 7-zone greybox" status claim elsewhere in the repo.
- Reflection probes were still placed for all 7 zones (harmless — an unused probe
  in an unbuilt zone just captures nothing until geometry exists).

### Audit: what exists vs what's missing (verified 2026-06-13)

The **wiring is coherent** — only the room shells are absent:
- **Zone graph** (entry script `main()`): `corp_zone↔vault_zone` (`enter_vault`),
  `corp_zone↔roof_zone` (`enter_roof`), `vault_zone↔lab_zone` (`enter_lab_e`),
  `roof_zone↔lab_zone` (`enter_lab_w`). ✅ both Lab approaches wired.
- **Doors** (`trigger_use` `zombie_door` + sliding `script_brushmodel` slab,
  `script_vector "0 0 130"`): all four exist with valid slab boxes at the zone
  boundaries — `acc_door_vault`/`acc_door_roof` (1250 pts, Corp side),
  `acc_door_lab_e`/`acc_door_lab_w` (1500 pts, Lab side). ✅
- **Spawners + features** in vault/roof: ✅ (risers, power switch `vault` at
  x2292 y2800, frag/EMP + sniper wallbuys, Overload/Helipad triggers).
- **Room shells (floor/ceiling/walls):** ✅ **injected** via `tools/gen_rooms.js`
  (skinned); ✅ **doorway gaps cut in the `.map` source** (2026-06-13) — Vault west
  wall + Roof east wall opened at both door-slab positions (below).

### Build spec — the two missing rooms (shells injected; cut doorways in Radiant)

✅ **Closed room shells injected** via `tools/gen_rooms.js` (worldspawn brushes,
one-shot). Each room = 6 brushes (floor, ceiling, 4 walls, 16u thick), a **fully
closed box** so it's **guaranteed leak-free** and compiles clean. Winding copied
verbatim from a verified box brush; already textured with the zone's materials
(vault = `t7_metal_painted_wall_dirty_grey` + `t7_metal_grate_flooring`; roof =
`t7_concrete_bare_weathered_01` + `t7_asphalt_damaged_dark_wet`). A reflection
probe already sits at each zone center. Footprints (interior, z0–128):

| Room | Interior (x, y) | Doorways (✅ CUT in source 2026-06-13) |
|---|---|---|
| **Vault** | x **[1000 .. 2400]**, y **[2490 .. 3170]** | **west wall** (x≈984–1000): Corp door @y≈2490–2536 (`acc_door_vault`); Lab door @y≈3120–3170 (`acc_door_lab_e`) |
| **Helipad** | x **[-2400 .. -1000]**, y **[2490 .. 3170]** | **east wall** (x≈-1000…-984): Corp door @y≈2490–2536 (`acc_door_roof`); Lab door @y≈3120–3170 (`acc_door_lab_w`) |

**DONE (2026-06-13):** doorway gaps cut directly in the `.map` worldspawn — the
Vault **west wall** (`ACCB0012`) and Roof **east wall** (`ACCB0023`) were each
reduced to their solid middle (y2536–3120), leaving a full-height gap at each end
aligned to the sliding slabs: Corp door @y2474–2536, Lab door @y3120–3186. Both
rooms now walk Corp→room→Lab. Built clean via the full pipeline (cod2map64 navmesh
OK from the `bin` cwd, LED, linker — `.ff` 2026-06-13 23:16). These are **greybox
openings** (full height, no frame/lintel). Optional Radiant polish later: door
jambs + lintel, raise the Vault ceiling, swap the Roof ceiling for a sky brush
(open-air helipad), add detail.

---

## 14. ⚠️ Custom wall/floor materials are BLOCKED on this install (do not re-fight)

After extensive investigation + live build experiments (2026-06-13), **custom
wall/floor material skinning does not work on this public-Steam Mod Tools install.**
The night sky, fog, reflection probes, and rooms all work; only painted **materials**
are blocked. Walls/floors are reverted to the stock greybox `script_wall` /
`script_floor_ceiling` (which render). **Root cause, proven, not guessed:**

- **Painting a custom/stock material on a brush face does NOT pack it into the
  usermap `.ff`.** Verified: a project material (`acc_wall_concrete`) and stock
  `t7_*` names are absent from the build's `.deps` + assetlist + `.ff` binary,
  while stock dev materials (`wc/script_wall`) ARE present. Only materials in the
  base ZM fastfiles (dev textures) or pulled as model/prefab dependencies pack
  from painting.
- **Forcing a pack via a `.zone` `material,<name>` line makes the linker COMPILE
  that material's techset shaders from source** — and the public tools ship the
  compiled shader **cache** but **not the shader source**. The compile dies:
  `failed to open source file: 'gbuffer_lit.hlsl' / 'techsetdef_buildshadowmap.hlsl'
  / 'techsetdef_unlit_simple.hlsl'`. Confirmed identical on the **Launcher GUI**
  and CLI. `lit` vs `lit_plus` makes no difference (both force the same compile).
- **No accessible source for those files.** They don't exist in the install
  (only `image.hlsl` is real source; the 174 `*.hlsl` under
  `share/assetconvert/ToolsGfx/shaders_modtools/v14/f8/` are `.lz4` compiled-cache
  dirs). The community **`LG-RZ/BlackOps3Shaders`** pack is a **PostFX** pack — it
  ships `lib`/`gfxcore` includes + custom POM/PSX geometry variants but **not**
  `gbuffer_lit.hlsl` or `techsetdef_buildshadowmap.hlsl`, and its custom geometry
  techset *also* needs the absent `build shadowmap depth` source. Installing it did
  **not** unblock vanilla materials (tested live, then reverted). Recovering the
  vanilla geometry shader source is an acknowledged **unsolved** community problem
  (olie304/BO3-Shader-Research).

**Ruled out (don't retry):** bare stock `t7` tokens; `material,` `.zone` lines for
brush materials; switching `lit_plus`→`lit`; image/variant names; copying stock
GDTs into `source_data` (dup-asset errors — `texture_assets` is already indexed);
`gdtdb` registration (was never the blocker); Steam "verify" / Additional Assets
(shaders absent by design); L3akMod (Lua only); the LG-RZ postfx pack for geometry.

**If revisited:** the only real avenues are (a) obtain a COMPLETE geometry shader
source set (`gbuffer_lit.hlsl` + `techsetdef_buildshadowmap.hlsl` + deps) and fix
the compiler include path — unsolved as of this writing; or (b) author materials
with a custom techset whose source IS shipped (POM/PSX look) — niche; or (c) build
the map on a different/older complete tools environment that has the shader source.
Until then: **greybox `script_wall` + the working sky/fog/probes atmosphere.**

---

## 15. Soundscape (audio) — see [docs/35](35_sound_plan.md)

This doc owns the map's *look*; **audio has its own spec in
[35 — Sound & Music Plan](35_sound_plan.md)** (atmosphere bed, per-zone reverb,
gameplay/elite reads, event cues, music). Short version so the atmosphere picture
is complete here:

- **Today:** [_acc_atmosphere.gsc](../scripts/zm/zm_abandoned_cyber_city/_acc_atmosphere.gsc)
  is **fog/visual only** — no ambient bed, no reverb, no music. The map ships 5
  stock `PlaySound` calls and nothing custom.
- **Target:** the neon palette maps to sound — cyan = live-tech hums/beeps, magenta
  = dead-nightlife muffle/silence, amber = dying-power buzz/flicker. Per-zone rain/
  city-drone bed; wet/cavernous undercity vs flatter plaza reverb.
- **Reverb is BSP-driven** (Radiant `ambient_room` volumes → stock presets via
  `ambient_mod.csv`), so the per-zone reverb pass (docs/35 Phase B2) is a full
  `cod2map64`+LED+linker build — same constraint as a sky/probe edit (§3, §9).
- **Licensing is identical to §8:** stock / self-authored / **CC0 only**. The
  `icegrenade.co.uk` asset index is **local-playtest only** (ToS forbids
  redistribution; ~95% game-rips) — never in the shipped `.ff`. See docs/35 §3.

---

Research dossier (full agent findings + sources) is in the workflow transcript;
verified facts are distilled here and in
[BO3_MAPMAKING_KB.md](BO3_MAPMAKING_KB.md).
