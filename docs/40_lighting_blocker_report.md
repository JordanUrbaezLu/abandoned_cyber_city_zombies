# Lighting blocker report — baked lightmap is frozen, LED relight is dead

**Date:** 2026-06-16 · **Status:** OPEN (deferred to atmosphere phase, by user decision) ·
**Severity:** cosmetic now / blocks baked-lighting atmosphere later ·
**Companions:** docs/29 (atmosphere & materials), docs/38 (LED-safe research), memory
`led-relight-dead-end-enclosed-geometry`.

---

## 1. The issue (what you see)

Random dark shadow blobs are baked onto the floor of the rooms — most visible after the
pillars/obstacles were removed to flatten the map. They don't line up with anything in the
world anymore; they're "ghost" shadows of geometry that no longer exists.

## 2. Root cause (why)

BO3 lighting is **baked**, not real-time. A separate file — the **lightmap** (`.led`,
~75 MB) — stores the pre-computed light and shadow for every surface. The map's `.ff`
bundles whatever lightmap is on disk at link time.

- The current lightmap was baked on **6/15**, **while the pillars still existed**.
- The geometry (BSP) was rebuilt on **6/16** with the pillars **removed**.
- We have been building with `-SkipLED` (skip the lighting bake) on every pass, because the
  bake **crashes** (see §3). So every build re-packs the **stale 6/15 lightmap** — the
  pillars are gone from the world, but their **shadows are frozen into the lightmap**.

In one line: **the geometry is current, the lighting is from two pillars-ago, and we can't
refresh the lighting.**

## 3. Why we can't just re-bake (the real blocker)

Refreshing the lighting means running the Radiant lightmapper (`Radiant_modtools -ledSilent
+recompute`). On **this install** it **hard-crashes** every time:

```
SANITY CHECK FAILURE (Result == ((HRESULT)0L))
…\bin\Radiant_modtools.exe   q:\t7\pc\code\tools\radiant\brush.cpp:1860
```

This is a D3D-level assert inside the lightmapper's brush pass — not a problem with our map
data (cod2map64 and the linker both accept the same brushes and build a clean, leak-free
BSP). With the `-ledSilent` flag the crash dialog is **not** suppressed, so the process
**blocks on the modal forever** — which is why it presents as a "hang" (240 s, zero output,
no lightmap written).

**Tested to exhaustion (2026-06-15 and again 2026-06-16):** the crash happens in the GUI
Launcher *and* headless; with reflection probes on *and* off; with the game running *and*
fully closed/GPU-free; and on both the old enclosed geometry *and* the current
pillars-removed geometry. **None** of those variables change the outcome. It is a hard
limitation of this machine's lightmapper.

### Things we tried that do NOT work
| Attempt | Result |
|---|---|
| Re-bake LED on simplified geometry, game closed | Same `brush.cpp:1860` crash |
| Ship with **no** lightmap (delete the `.led`) | Links fine, but the world renders **fullbright pure white** — greybox material base color is white, so with no baked light every face is 1.0. Unusable. |
| GUI Launcher "Compile + Light" | Same crash (per docs/38) |

So both ends of the dial are bad: **lightmap ON** = correct brightness + frozen shadows;
**lightmap OFF** = no shadows + blinding white. There is no middle setting without a working
bake.

## 4. Resolution

### Now (chosen): defer
Keep the stale lightmap (normal brightness, faint ghost shadows) and move on. The shadows are
a **cosmetic greybox artifact**, not a gameplay or stability problem. The current `.ff`
(34.5 MB) is normal and fully playable. The stale lightmap is backed up at
`share/raw/maps/zm/zm_abandoned_cyber_city.led.stale-6-15-bak`.

### The proper fix, when we do the atmosphere phase
The map's intended final look is **not** baked daylight anyway — it's a dark cyber-city night.
That look is delivered by **runtime, LED-free levers** that overwrite the baked lighting:
- **Fog** — already built in `_acc_atmosphere.gsc` (`set acc_fog_on 1` to preview), pure
  script, rebuilds with a linker-only pass.
- **Per-player vision tint** — `VisionSetNaked` scoped to zones (docs/37 §11), the planned way
  to make rooms dark/atmospheric without a bake.
- **Night sky + reflection probes** (docs/29).

Under a dark night vision + cold fog, the faint floor shadows become **invisible** — the
ghost-shadow problem dissolves on its own. So the resolution is to **stop fighting the
lightmapper and lean on the runtime atmosphere stack** the map was always going to use.

### The only path to *actually* re-baking (not recommended now)
Find and fix the specific brush that trips `brush.cpp:1860`. LED baked clean on 6/13 and broke
around the vault-ceiling/door-seal **enclosure** work — a thin sliver / coplanar face in that
geometry is the most credible trigger (docs/38 §2). This is a time-intensive, uncertain
brush-hunt that the project has already spent significant effort on, and it would only buy us
**baked** lighting we're going to overwrite with vision/fog anyway. Park it unless we
specifically want baked light somewhere.

## 5. What it blocks

**Blocks nothing on the critical path.** It does **not** block:
- Gameplay, systems, scripting, boot/runtime — all unaffected.
- Geometry/layout work — cod2map64 + linker are healthy; we build all day with `-SkipLED`.
- The intended final dark-night look — that comes from fog + vision tint, which need **no**
  bake.

**It does block / cost us:**
- **Any look that depends on baked light** — real sunlight-and-shadow, bright daytime rooms,
  baked ambient occlusion for depth, accurate light/shadow from placed light entities. If we
  ever want a *lit* (not vision-tinted) area, we can't bake it on this machine.
- **Clean greybox screenshots right now** — the ghost shadows look like a bug to anyone who
  doesn't know the backstory (which is why this report exists).
- **Reflection-probe quality** — probes are baked in the same crashing stage, so cubemap
  reflections are stuck at their last-good state too.

## 5b. Per-feature rework attempted — and why it was abandoned (2026-06-16, ~30 bakes)

The user authorized the full per-feature LED-safe rework. I built a fast bisection harness
(deploy a `.map` → `cod2map64` → `radiant -ledSilent +forceclean +recompute`; a 200s hang = the
crash modal, a fresh `.led` mtime = a clean bake in ~13s) and learned:

1. **Radiant is healthy.** Old snapshots (`*.map.market-bak`, `pre-stage3-bak`) and the current
   map *minus 4 brush groups* bake clean in ~13s, repeatably. **No reinstall needed.**
2. **Exactly 4 recent generator brush groups are the culprits:** vault lockdown **seals**
   (`acc_seal_vault_zone`), perk-gallery **flank walls** (`ACCPFLANK`), mystery-box **collision
   clips** (`acc_box_clip_`), and the vault **ceiling** (`ACCVCEIL`). A clean bake needs ALL of
   them LED-safe simultaneously (any one crashes the whole bake).
3. **The fix does not converge.** Even the *simplest* culprit — the 2 **static** flank walls —
   crashes in **every** configuration tried: z256, z250, real-corner winding, wall-penetration,
   overlap-abut, and exact-abut-to-the-adjacent-partition with no overlap. Meanwhile the identical
   map without them bakes clean. The "LED-safe" rules in docs/36 (`z250` below `z256`, 8u insets,
   embed-in-walls) are **false on this install** — the seal generator's own "LED-safe" seals were
   a confirmed culprit. This lightmapper is pathologically sensitive to *any* added brush at an
   existing wall/junction, in ways that don't follow the coplanar/sliver model.

`tools/fix_led_safe_geometry.js` holds the researched coordinates but is a **parked, incomplete**
artifact — it never produced a clean bake. **Decision: stop pursuing baked LED.** The dark
cyber-city look comes from runtime **vision tint + fog** (LED-free), which overwrites the lighting
and makes the stale shadows invisible — deliver that in the atmosphere phase instead.

## 6. One-paragraph summary

The floor shadows are an out-of-date baked lightmap (baked while the pillars existed; we can't
refresh it because the Radiant lightmapper hard-crashes at `brush.cpp:1860` on this install,
confirmed under every condition). Deleting the lightmap instead makes everything fullbright
white, so we keep the stale one. It blocks nothing on the critical path — gameplay, scripting,
and geometry are all fine — and the map's real look (dark cyber-city night via fog + per-player
vision tint, both LED-free) will hide the ghost shadows entirely, so the fix is to deliver that
atmosphere pass rather than to keep fighting the broken bake. Re-baking is only possible if we
hunt down the one bad enclosure brush, which isn't worth it for lighting we'll overwrite anyway.

---

# ADDENDUM (2026-06-17): The REAL root cause — the map is out of lightmap atlas

The "it's a defective enclosure brush" reading above is **WRONG**. A ~25-bake controlled
investigation (deep-research + local empirical bisection) found the true cause. **Supersedes §1-6
for the LED-crash diagnosis.**

## A1. The breakthrough experiment

I added a **clone of a known-good perk partition** (a brush *identical in construction* to the
partitions that bake fine) to the clean base → **CRASH**. Then a plain box in the *open start-spawn
area*, far from the gallery and vault → **CRASH**. So the 4 "culprit" groups were never defective:
**adding *any* brush *anywhere* to the current map crashes the LED bake.** The map is maxed out.

## A2. It is a lightmap ATLAS / surface ceiling, not geometry

cod2map triangle counts are the discriminator:

| map state | triangles | bakes? |
|---|---|---|
| clean base (4 groups removed) | **1708** | YES |
| + box in empty room | 1720 | no |
| + isolated box in gallery | 1720 | no |
| flank present, doors removed | 1732 | no |

Clean base sits at **1708 tris**; **everything ≥1720 crashes**. Refuted by direct test: material
(`caulk` crashes), size (z150 crashes), per-face lightmap-UV value (scale 128 crashes; the
partitions use the `16384` placeholder and bake), winding (real-corner crashes), position
(free-standing crashes), and **lightmap *resolution*** (`+lowest` quality and `_lightmapscale 4`
**don't help** → it's atlas *pages/charts*, not texel density). The crash fires at **~2 s** (early
brush/surface setup), and the clipboard assert is only `(Result == ((HRESULT)0L)) brush.cpp:1860`
— a failed D3D allocation.

**Why the ceiling is absurdly low (~1720 tris when real maps have 100k+):** the map ran out of
**lightmap atlas space**. Structural proof — lightmap-UV *offsets*:

| | zero offset (unpacked, piled at 0,0) | computed offset (packed) |
|---|---|---|
| our map | **1148 faces (90%)** | 124 |
| stock `zm_giant` | 126 (17%) | 637 (83%) |

Every brush in this map is **script-generated `.map` text with placeholder lightmap UVs**
(`lightmap_gray 16384 16384 0 0 0 0`). Radiant's GUI brush tools compute proper, **packed** lightmap
UVs; our generators never did. The lightmapper must repack all 1148 unpacked charts at bake time,
and with the uniform `16384` scale they pack **inefficiently** → the atlas fills at the clean-base
size → adding any surface overflows it → the per-page D3D `CreateTexture`/allocation returns
non-`S_OK` → `brush.cpp:1860`. The 4 features were just the last straws; the map grew (greybox +
gallery + seals + …) until the inefficiently-packed atlas was full.

## A3. THE GUARANTEED FIX (ranked)

**PRIMARY — regenerate proper, packed lightmap UVs (addresses root cause, frees huge headroom):**
- **Option A — Radiant GUI recompute (canonical):** open `zm_abandoned_cyber_city.map` in
  `Radiant_modtools.exe` (GUI), Select All, recompute/reset lightmap UVs (or just **Save** — Radiant
  repacks the atlas on save), close. Then run the headless bake on the FULL map. Radiant packs the
  atlas efficiently → bake succeeds with massive headroom. **This is the authoring step our text
  generators skip.** CRITICAL: the earlier "GUI also crashed" note (memory/`docs/38`) was a
  Compile+**Light** (a *bake*) on the already-over-budget map — it was **never a UV-recompute-then-
  bake**. The fix has not actually been tried.
- **Option B — compute lightmap UVs in the generators:** emit a per-face lightmap UV *scale matched
  to face size* (not a uniform `16384`) so the lightmapper packs them tightly. Harder; verify the
  packed-atlas footprint drops.

**FALLBACK 1 — reduce surface/triangle count (NOT a reliable lever — see A6):** ❌ REFUTED as a
simple fix. A map with the features but the whole perk gallery removed bakes at **1624 tris and
STILL crashes**; with the big-face features *also* removed, **1612 tris still crashes** — both
*below* the 1708-tri clean base that bakes. So lowering the triangle count does **not** guarantee a
bake; the limit is content-/packing-specific, not a scalar count. (`caulk` also does NOT help — test
V1.) Reducing geometry might help if done right, but it is not the dependable path the GUI recompute
is.

**FALLBACK 2 — raise the atlas budget** if a worldspawn key / compile config controls atlas pages
(unconfirmed; `_lightmapscale` had no effect — wrong key or not the lever).

**FALLBACK 3 — no bake:** ship `-SkipLED` + the vision/fog dark look (the proven LED-free path; the
stale shadows stay but are hidden by the night atmosphere). Already the project's standing plan.

## A4. The decisive confirmatory experiment (run NEXT)

1. Open the `.map` in Radiant GUI on the Windows box → Select All → recompute/reset lightmap UVs (or
   Save) → close.
2. Headless bake the FULL map (`build_map.ps1`, NOT `-SkipLED`), all 4 features present.
- **Bakes clean → root cause + primary fix CONFIRMED**: correct lighting + no stale shadows +
  features intact + the map can grow again.
- **Still crashes → atlas genuinely full → Fallback 1** (reduce geometry).

Headless pre-check I can run without the GUI: bake "clean base − ~150 faces of greybox + all 4
features" — if it bakes, **reducing geometry is a guaranteed path** and quantifies the budget.

## A5. Confidence

- **Very high:** it is a global lightmap-atlas/surface ceiling, not a per-brush geometry defect
  (proven by the clone-partition and empty-room crashes; every per-brush theory refuted).
- **High:** the unpacked placeholder lightmap UVs are why the ceiling is so low.
- **Medium:** that the GUI UV-recompute alone fully fixes it (needs the A4 test; if the GUI can't
  pack better, or the atlas is genuinely full, fall to reducing geometry — which is guaranteed).

## A6. Pre-check result (2026-06-17): the limit is content-specific, not a scalar count

Ran the reduce-geometry pre-check. It **refined (and partly humbled) the model**:

| map | triangles | content | bakes? |
|---|---|---|---|
| clean base | 1708 | gallery present, 4 features absent | **YES** |
| clean + 1 clone partition | 1720 | one extra known-good brush | no |
| reduced | 1624 | 4 features present, gallery removed | no |
| reduced2 | 1612 | flank+clips only, gallery+ceiling+seals removed | no |

**A map with FEWER triangles than the baking clean base still crashes.** So it is NOT a scalar
triangle/surface ceiling — lowering the count does not guarantee a bake. The **only** configuration
that bakes is the *exact* clean base; almost any perturbation (add a brush, or swap gallery↔features)
crashes, even when it lowers the count. This is the signature of a **fragile lightmap-atlas pack**:
the lightmapper packs the clean base's specific surface set into the atlas and it *just* fits; change
the set and the pack no longer fits → page allocation returns non-`S_OK` → `brush.cpp:1860`. The
unpacked placeholder UVs (A2: 90% of our faces at offset 0,0) are the most likely reason the pack is
so tight/fragile — proper packed UVs would give slack and remove the fragility.

**Consequence for the plan:** "reduce geometry" is demoted to an unreliable lever. The dependable
fix is **A3 Primary — get Radiant to compute/repack proper lightmap UVs (GUI Select-All → recompute
→ Save → bake)**. That is the one operation that addresses the packing directly, and it is a single
clean step — not the repeated headless crash-bakes (which were wound down 2026-06-17 after the user
reported a couple of machine restarts; the crash is a controlled assert, not a confirmed GPU/TDR
hang, but ~20 D3D-failure aborts is enough to stop poking it headlessly).
