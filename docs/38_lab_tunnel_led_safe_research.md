<!-- Research report (read-only investigation, 2026-06-15). Companion to docs/36 (map-tightening) + docs/37 (punishing the middle). Generated from a 10-agent read-only workflow; literals re-verified vs the live .map. -->

# LED-safe enclosed lab-approach tunnels + maze cover

Research report + implementation-ready recipe. Status: RESEARCH ONLY — no geometry/code changes. Coordinates and brush IDs below were re-verified against the live `map_source/zm/zm_abandoned_cyber_city.map` on 2026-06-15; a concurrent agent owns the file, so re-verify literals before authoring.

---

## 1. Executive summary

**Yes — enclosed, lit, navmesh-valid lab tunnels with maze cover are buildable cleanly, but the dossiers' headline causal model ("a coplanar z256 ceiling cap crashes LED") is only one of three candidate triggers and is *not* proven; the strongest-supported root cause is headless-LED instability, with thin near-coplanar slivers as the only credible geometric contributor.** The safe, decision-ready approach: (a) **rebuild each corridor as ONE watertight closed tube that REPLACES the existing open-top z256 side walls** (do not drop a separate cap onto them) — this neutralizes the coplanar question entirely; (b) light each tube with the **verified-real kelson8 `classname light` / `PRIMARY_OMNI` block (radius ~150, stops ~6, spawnflags 82, NO `def` key)** plus a correctly-contained per-tunnel reflection probe; (c) keep maze cover as standalone closed boxes with **≥96u lanes and no 8u-off-wall slivers**; (d) **diagnose LED first** (rebuild the current open-top map headless twice, or do the bake in the Radiant GUI) before assuming geometry is at fault. Because the relight is the only fragile stage and is reported nondeterministic after force-kills, treat any single clean bake with suspicion and confirm a **fresh `.led`/lighting mtime + in-game lit tunnel**, not just a fresh `.ff`.

The two adversarial verifiers (LED-HYPOTHESIS and RELIABILITY) substantially **corrected** the optimistic dossiers: the coplanar-crash claim is contradicted by the repo's own record of a clean LED bake of the coplanar-overlapping gen_rooms shells (2026-06-13), and the "GUI-relight is reliable / clear-cache fixes it" claims have **zero repo backing** and must be verified live. I have used the corrected values throughout and flag each correction.

---

## 2. Why the LED relight crashed — reconciled and verified

### 2.1 What is actually known (verified facts)

- **The crash signature:** `radiant_modtools -ledSilent +recompute` exits `0x80000003` / `-2147483645` / `-1`, writes **no `.led`**. `cod2map64` (BSP + navmesh) and the `linker` are unaffected. Source: `apply_room_shrink.js:78-93`, `CHANGELOG.md:156-163`.
- **It fired on the lab-corridor enclosure attempt** (ceilings `C0/C1` + maze `M0-M3`), and per `apply_room_shrink.js:85-89` **both** the flush-coplanar variant **and** the 8u-off-wall variant crashed.
- **Headless LED is explicitly flagged FLAKY**: "same geometry that relit fine earlier later crashed" after "repeated runs + a force-kill" (`CHANGELOG.md:160-162`). This is the single most important fact and the verifiers are right to weight it heavily.
- **The map has ZERO `light` entities** (verified: `grep "classname" "light"` = 0) and **7 `reflection_probe`** entities (verified). It is lit by sun + ambient only.

### 2.2 Three candidate triggers — reconciled with the verifiers

The six dossiers asserted, with varying confidence, three causes. The two verifiers (LED-HYPOTHESIS, RELIABILITY) tested them against repo evidence:

| Candidate trigger | Dossier claim | Verified verdict |
|---|---|---|
| **(A) Coplanar overlapping faces** (cap bottom z256 flush on the z256 wall tops) | Asserted as THE cause by MECH/SHIPPED/DESIGN-INTENT/NAVMESH | **NOT proven; partly contradicted.** The gen_rooms vault/roof shells contained a coplanar OVERLAPPING double-floor at z0 and a flush ceiling-on-wall at z128, yet went through a **CLEAN LED recompute** in the 2026-06-13 doorway-cut build (`CHANGELOG.md` doorway-cut entry; shells deleted only at Stage 2). So a coplanar-overlap config *did* bake. Also the disabled lab ceiling `C0` was z[264,280] — bottom z264 is **8u ABOVE** the z256 wall tops, i.e. **not coplanar** — yet still crashed. The repo data points the *opposite* way from the strong form of this claim. |
| **(B) Thin slivers / near-coplanar gaps** (the 8u-off-wall maze blocks) | Raised by MECH/SHIPPED | **Most credible geometric contributor.** An 8u gap between two parallel lit faces is a genuine lightmap-degenerate hazard. Explains the maze blocks, **not** the ceiling. Mitigation is cheap and certain (keep lanes wide), so adopt it regardless. |
| **(C) Enclosed = no sky light = crash** | Asserted by LED-RELIABILITY (its primary thesis) | **FALSE as a crash cause.** An unlit enclosed BSP bakes **black**; it does not crash the lightmapper. This is a **playability** requirement (add light), NOT a crash fix. Both verifiers and ENCLOSED-LIGHTING agree. Keep the light, but do not call it a crash fix. |

> **MECH cited `zm_giant.map:632-637`** for the crash mechanism. The LED-HYPOTHESIS verifier flagged this file as **absent from the repo** (no such path under `map_source/` or `tmp/`); it is unverifiable and should not be relied on.

### 2.3 Best-supported root cause (corrected reading)

**Dominant factor: headless-LED nondeterministic instability** (`-ledSilent +recompute` aborting flakily after repeated invocations + force-kills), **not** a specific brush adjacency. **Secondary plausible geometric contributor: thin slivers** from the 8u-off-wall maze blocks. The "enclosure/no-light" theory is the weakest and is discarded as a crash cause. The 2026-06-13 clean-LED build of the coplanar shells is the strongest single data point and it directly undercuts the coplanar-crash claim.

**Caveat to confirm at build time (open question O-1 in the doorway-cut build):** was that 2026-06-13 LED bake *genuinely* clean, or did the pipeline pack a `.ff` over a silent LED failure (the project's known "success = fresh `.ff` not exit code" pattern)? Confirm a fresh `.led` timestamp from that build before treating it as ironclad proof. Either way, the strong coplanar-crash claim is unsupported.

### 2.4 LED-safe authoring rules for THIS map (the general rules)

1. **Prefer rebuilding a region as one self-contained closed solid over capping pre-existing geometry.** A single watertight box has no "another brush's parallel face" to be coplanar/overlapping with — it sidesteps trigger (A) by construction. (This is *why* the gen_rooms shells were clean: each was its own 6-faced box.)
2. **Never leave a thin (≤~16u) lit gap between two parallel faces** (trigger B). Keep cover either flush-and-fully-contacting a wall, or a clean ≥64u (ideally ≥96u) clear gap. **Bottom-of-brush coplanar with the floor at z0 is proven fine** (the Stage-1/2 stalls and start cover S0/S1 bake clean).
3. **Treat headless `-ledSilent` as nondeterministic.** Do ONE clean attempt per change; if a build you believe is clean crashes, **restart `radiant_modtools` fresh** (or use the GUI bake) before blaming the geometry. Do not hammer-retry.
4. **An enclosed volume needs its own light + reflection probe** — for visuals, not to avoid a crash.
5. **Materials: ONLY `script_wall` (vertical) and `script_floor_ceiling` (horizontal) with the verbatim UV** `128 128 0 0 0 0 lightmap_gray 16384 16384 0 0 0 0`. The ASSET-FORMAT verifier confirmed these are the *only* rendered-face tokens in the live (packing) map. **`t7_*` and custom tokens are BLOCKED on this install** (they force the linker to compile absent techset HLSL → build dies). Note `gen_rooms.js`'s `room()` defaults still *name* `t7_*` materials (lines 65-68) — those never reached live faces; do not re-run that generator without overriding them.
6. **`caulk_shadow` is NOT present in stock on this install** (ASSET-FORMAT verifier: grep = 0). Do not author it expecting it to pack. A fully closed solid shell is the substitute for blocking light leak. `clip`/`clip_ai`/`clip_physics` ARE real stock tool materials if needed for AI shaping.

---

## 3. The LED-safe geometry recipe

### 3.1 Verified anchor coordinates (live map)

- **lab_e corridor:** walkable X[819,1119], Y[3120,3336] (the 216u lane is Y3120→3336 between 20u stubs; floor brush 93 spans Y[3100,3356]). Side walls = **brushes 94 & 95, z[0,256]** (confirmed z256 wall tops at lines 921/931).
- **lab_w corridor:** walkable X[-1119,-781], Y[3120,3336]. Side walls = **brushes 97 & 98, z[0,256]** (lines 951/961).
- **Door slab `acc_door_lab_e`** (entity 101): box z[0,128] at X[961,977]; `script_vector "0 0 130"` → slides UP to **z258 when open**. `acc_door_lab_w` (entity 103): z[0,128] at X[-958,-942], same +130.
- **PaP blockers:** `acc_pap_block_server` (entity 104) z[0,256] at X[1040,1056]; `acc_pap_block_roof` (entity 105) z[0,256] at X[-1056,-1040]. Both span the full Y[3120,3336] lane.

### 3.2 Recommended construction — ONE watertight tube per corridor (replaces open-top walls)

This is the corrected, lowest-risk approach (per the LED-HYPOTHESIS and SHIPPED verifiers): **delete the existing open-top z256 side-wall brushes for the corridor span and author a fresh closed tube** so no new face is coplanar+overlapping with anything pre-existing. Use the verified `gen_rooms.js box()` winding (lines 30-43; the door slab/PaP blocker boxes use this exact 6-plane order).

Per corridor, author these solid boxes (`box(x0,y0,z0, x1,y1,z1, mat, guid)`), all material `script_wall` except the floor/ceiling = `script_floor_ceiling`:

**lab_e** (mirror X for lab_w with X → [-1119,-781]):
- **Floor:** already exists (brush 93, z[-16,0]) — keep it; do NOT add a second floor at z0 (that was the gen_rooms double-floor z-fight).
- **South wall:** `box(819, 3100, 0, 1119, 3120, 256)` — replaces the south stub face of old brush 94 region.
- **North wall:** `box(819, 3336, 0, 1119, 3356, 256)`.
- **West (lab-side) end:** leave the lab-side mouth OPEN (this is the un-welded approach mouth). Do not cap X819.
- **East (spoke-side) end:** the door slab + PaP blocker already occupy this; do not add an end wall.
- **Ceiling:** `box(819, 3100, 256, 1119, 3356, 272)` — bottom face at **exactly z256**, sitting on top of the new side walls **edge-to-edge** (the wall tops at z256 meet the ceiling box's SIDE faces, not its bottom face, because the ceiling box footprint matches the outer wall footprint). This is the one-box-replaces-walls reading; the ceiling bottom is the ONLY face on the z256 plane over the walkable footprint.

> **Why z256 (not z264) is now safe:** the disabled `C0` cap crashed at z264 *because it was a separate cap over still-present z256 walls* — an 8u sliver plus a doubled structure. When the side walls are part of the same fresh tube, the ceiling bottom at z256 is flush with the wall *tops* in a clean edge-to-edge solid join (the proven-safe seam class, like cover-bottom-on-floor at z0), not an overlapping back-to-back face. **This must be confirmed by the live one-shot LED test (O-1 below); if z256 still crashes, raise the ceiling bottom to z260 — see 3.3.**

### 3.3 Fallback construction — floating cap at z≥260 over the existing walls

If deleting/rebuilding the side walls is undesirable, keep brushes 94/95/97/98 and add a ceiling slab whose **bottom is at z260** (`box(819, 3100, 260, 1119, 3356, 276)`), 16u thick. This leaves a deliberate 8u reveal between wall top (z256) and ceiling bottom (z260) — **non-coplanar**, and clears the door's z258 open travel. This is lighter (no wall rebuild) but **re-introduces the very 8u parallel-gap sliver hazard** (the wall outer face and ceiling side face). It is the *riskier* option per the verifiers; only use it if the one-box rebuild is blocked.

### 3.4 Door-open clearance (HARD constraint, verified)

The door slab opens to **z258**. A ceiling bottom at z256 (option 3.2) sits **2u below** the open slab top — it would **trap the sliding slab**. **This is a real conflict the DESIGN-INTENT dossier flagged and it is confirmed by the live `script_vector "0 0 130"` on a z[0,128] slab.** Two resolutions, decide at build time (O-2):
- **Recess pocket:** notch the ceiling above the slab footprint (X[961,977] / X[-958,-942], full Y lane) up to z≥260 so the slab fully hides into a pocket.
- **Re-spec the door slide** to +124 (top → z252) so it clears a z256 ceiling. (Changes `script_vector` — a GSC/map data edit, coordinate with the editing agent.)
- The **fallback z260 ceiling (3.3)** sidesteps this entirely (slab top z258 < ceiling z260), at the cost of the sliver risk.

### 3.5 Do NOT overlap the PaP blockers or door slab

Ceiling spans *above* the z[0,256] PaP blockers and z[0,128] door slabs are fine (different z band for the ceiling at z256+). **Maze cover must be placed clear of both footprints** — keep maze on the **lab side** of the PaP blocker (X<1040 for lab_e, X>-1040 for lab_w) and clear of the slab X[961,977]/X[-958,-942]. A cover box overlapping a blocker/slab brush creates exactly the coplanar/overlap geometry we are avoiding.

---

## 4. Lighting recipe

### 4.1 The light entity — VERIFIED-REAL kelson8 PRIMARY_OMNI block (corrects the LIGHT dossier)

The ENCLOSED-LIGHTING dossier quoted "PRIMARY_OMNI radius 180 stops 13 def white_light spawnflags 82" from `alien main_light.map:27-66`. **The ASSET-FORMAT verifier corrected this: that alien entity is actually a PRIMARY_SPOT (radius 144, stops 14.2, spawnflags 84), and `def white_light` is UNVERIFIED on this install (grep of source_data + share/raw = 0).** Use the **kelson8 PRIMARY_OMNI block, verified verbatim** on this exact public-Steam install (`tmp/kelson8_testmap/.../zm_test_map.map:3792-3818`, confirmed by me this session). **NO `def` key.**

Exact verified KVP set (one per corridor, more for a long run):

```
{
"classname" "light"
"origin" "969 3228 200"          // lab_e center, near ceiling; lab_w = "-969 3228 200"
"stops" "6"
"ENABLE_FALLOFF" "1"
"PRIMARY_NOSHADOWMAP" "1"
"PRIMARY_TYPE" "PRIMARY_OMNI"
"_color" "0.6 0.8 1"             // cool cyan for the cyberpunk read (kelson8 ships "1 1 1")
"bake_intensity_scale" "1"
"client_server" "ClientSide"
"def_tile" "1 1"
"excludeDedicated" "Off"
"falloffdistance" "12"
"far_edge" "0.949999988079071"
"fov_outer" "90"
"lightingstate1" "1"
"lightingstate2" "1"
"lightingstate3" "1"
"lightingstate4" "1"
"name" "light"
"penumbraRadius" "1.5"
"radius" "150"                   // ~150 to span the 216u-wide / ~300u-long tube (kelson8 omni = 100)
"roundness" "0.5"
"shadowUpdate" "Never"
"shadowmapScale" "1"
"superellipse" "0.75 1 0.75 1"
"volumetricSampleCount" "8"
"spawnflags" "82"
}
```

- **DROP `def white_light`** — it has no GDT backing here (grep=0) and all 23 working kelson8 lights omit it. Adding it risks a missing-def hard error.
- **Placement:** z~200 (below the z256+ ceiling, above head height), centered in the lane, **clear of the slab/blocker/ceiling slab**. For a ~300u-long tube one omni suffices; two (e.g. Y3160 and Y3300) give an even bake.
- **Light entities are a new asset class for this map** (currently 0). Whether they need a `.zone` manifest line on this install is an **open question (O-3)** — light entities are worldspawn-baked (likely no line needed), but unverified. Confirm at first build: the linker will error on an unresolved asset if one is required.

### 4.2 Reflection probe — add one per tunnel AND fix the existing malformed boxes

- **Add one `reflection_probe` per enclosed corridor**, origin inside the tube (e.g. `969 3228 120` / `-969 3228 120`), copying the existing `acc_probe_*` KVP shape (`box 1`, `resolution 8x`, `client_server ClientSide`), **but size it to the tube interior** (~half-extents X150 Y108 Z128) with the **inner ball strictly contained in the outer cube**. Place BEFORE the LED pass.
- **VERIFIED LATENT HAZARD — fix the 7 existing probes:** all 7 `acc_probe_*` share an identical, **malformed** box: `size_max "712.25 544.75 198.25"` but `size_min "634.5 548.5 73.25"` — the **size_min Y (548.5) EXCEEDS size_max Y (544.75)**, so the inner ball is NOT contained on the Y axis. This is one of the documented top LED-crash triggers (inner ball not inside outer cube) and a credible co-factor in the flakiness. Both verifiers (LED-RELIABILITY, RELIABILITY) flagged it. **Independently of the tunnel work, these 7 boxes should be corrected** (size_min ≤ size_max on every axis) and, post-shrink, resized so none overlaps the now-smaller room walls. Do NOT copy the malformed box into new probes.

### 4.3 Does a sky-gap alone suffice? (NO — recommend against)

ENCLOSED-LIGHTING and DESIGN-INTENT both float a "thin skylight slot" to let sky light in without a light entity. **Recommendation: do NOT rely on a sky gap.** It (a) defeats the punishing-enclosure design goal (sightline denial / commitment), (b) risks new coplanar/leak geometry around the slot, and (c) the exact stock sky-portal material token is an unresolved open question (MECH/O-5). A `light` entity + probe is the verified, self-contained path. Keep the sky-gap idea only as a last resort if light entities turn out to need an unavailable asset.

---

## 5. Maze / cover recipe

### 5.1 Verdict from the NAVMESH dossier — corridor is the WRONG place for a maze

The NAVMESH dossier's analysis (corroborated by DESIGN-INTENT and docs/36) is the load-bearing gameplay finding: the **216u corridor is too tight to maze**. It is at/below ACC's documented 192–256u horde-train lane floor, already holds a full-width PaP blocker (z[0,256]) + a sliding door, and chicane cover would pinch the effective lane to ~90–130u (the documented "row-of-tables stuck" case) — a navmesh pinch + Brutus straight-charge wall-trap = a banned "cheap death." **Enclose the corridors for atmosphere; deliver the actual risk-cover in the adjacent vault/roof rooms.**

### 5.2 Recommended: cover gauntlet in vault_zone / roof_zone (the real approach areas)

- **vault_zone** (live footprint after Stage-3 shrink: X[1119,1744], Y[2260,3400]) and **roof_zone** (X[-1744,-1119], Y[2260,3400]) are the 1100+u-wide rooms that already host the spawners and feed the lab corridor mouths.
- Place a **staggered serpentine of 3–4 waist/chest-high cover blocks** in band ~Y[2700,3050], so zombies must weave to reach the lab door. Each block:
  - Standalone closed `script_brushmodel` box (auto-DisconnectPaths), **z[0,72-96]** (shoot over, block sightline), ~140u footprint, using the proven market-stall / start-cover S0/S1 winding (bottom coplanar with floor z0 = proven safe).
  - **Gaps alternate sides**, every lateral lane **≥192u (target 256u)**.
  - **≥96u clearance from every riser/dog spawner.** Vault risers are X[1275,1588] Y[2545,3115] + dog at (1431.5, 2830); keep the cover band **south of ~Y3050** so it does not bury the northern risers at Y3115 that sit at the corridor mouth.
- For any **angled** cover, cap with a `clip_ai` brush so navmesh sees a clean obstacle (zm_alien_isolation pattern; `clip_ai` is verified-real stock). Axis-aligned boxes do not need it.

### 5.3 If maze cover is still wanted INSIDE the tunnels (against recommendation)

Keep it to a single light chicane, **never spanning the lane**, **≥96u lanes**, blocks **≥64u off the side walls (never 8u — the verified sliver crash)** OR flush-and-fully-contacting a wall. Bottom at z0. Stay clear of the slab/blocker footprints. This is higher-risk and lower-value than the room gauntlet; only do it if the room gauntlet proves insufficient in playtest.

### 5.4 Navmesh validity

`cod2map64` auto-builds the zombie navmesh around any solid worldspawn/script_brushmodel cover; **static cover needs no `DisconnectPaths` and no clip** (the buyable doors/PaP blockers use DisconnectPaths because they toggle at runtime). The ceiling does NOT affect navmesh (ground-only zombies). The maze blocks DO — **full `cod2map64` regen required**, verified via `_navmesh.hkt` mtime newer than the edit. `cod2map64` MUST run with cwd = `<tools>\bin` or navmesh gen silently aborts and the `.hkt` goes stale (zombies path the old layout).

---

## 6. Reliable build / relight procedure

> The RELIABILITY verifier's key correction: the "GUI-relight is reliable" and "Clean-Xpacks / clear-cache fixes the crash" claims have **ZERO repo backing** — they are hopeful clauses in `CHANGELOG.md:160-163` / `apply_room_shrink.js:92`, never run on this split install, and the Launcher Run path is documented broken (`docs/23:60-63`). Treat ALL relight-reliability mechanisms as **unverified on this install**. The headless `-ledSilent` path is the only relight wired into the repo. The "ship stale lightmaps" fallback is real (`build_map.ps1:173-181`) but is **NOT viable for an enclosed tunnel** (it would ship black).

### Step-by-step

0. **DIAGNOSE FIRST (no enclosure yet).** Rebuild the CURRENT open-top map headless **twice in a row**. If a previously-clean build now crashes, flakiness dominates and the geometry hypothesis is moot — fix the tooling state (fully restart radiant; do not force-kill mid-bake) before authoring anything. This is the single experiment that separates tooling-flakiness from geometry and the repo never ran it.
1. **Author the geometry** (one-box tube §3.2, lights §4.1, per-tunnel probe + fix the 7 malformed probes §4.2).
2. **Sync:** `.\tools\sync_to_modtools.ps1` (the linker compiles the DEPLOYED copy, not the repo).
3. **BSP:** `cod2map64` with **cwd = `<tools>\bin`** (`-navmesh`). Verify: no leak, 0 degenerate tris, no "Unable to load navigation mesh generation settings", `_navmesh.hkt` mtime fresh.
4. **Relight:** `radiant_modtools -ledSilent +medium +localprobes +forceclean +recompute` on the map, **one clean attempt**. If it crashes on geometry you believe is clean, **fully restart `radiant_modtools` and retry once** — do not loop.
   - **If headless keeps crashing:** the GUI bake (F9 game-view → F8 lighting → exposure-bolt → Export on close → Launcher light-compile) is the dossiers' suggested fallback, **but it is UNVERIFIED on this split install and the Launcher Run path is documented broken** — verify it works live before relying on it (O-4). Do not document it as reliable until proven.
5. **Linker:** repack the `.ff`.
6. **Confirm a REAL relight (critical):** a fresh `.ff` is the LINKER oracle only and does NOT prove lightmaps updated. Confirm **(a) a fresh `.led` / lighting (zone xpak) mtime advanced past the map edit**, AND **(b) in-game the tunnel is LIT, not black**. Do NOT delete zone-folder xpak files.
7. **Verify gameplay:** `developer 1; ai_shownavmesh 1` — zombies path the tunnel and weave the gauntlet without bunching; door opens (slab clears the ceiling); both approaches reachable when un-welded.

### Fallback ladder

1. One-box tube, headless, z256 ceiling (preferred).
2. If z256 crashes the bake → floating z260 cap (§3.3), headless.
3. If headless still crashes on clean geometry → GUI bake (verify live first), then headless `cod2map64 + linker` only with the build's SkipLED switch.
4. **Never** ship the enclosed tunnel on a stale/crashed LED (black corridor).

---

## 7. Design fit

This satisfies the docs/37 "punish the middle" intent while preserving every hard rule:

- **Risky lab approach / commitment:** an enclosed, lit-but-claustrophobic tube reads as commitment + sightline denial (can't see what's ahead, no free open-floor kite loop) — the deliberate contrast to the open poles, exactly the docs/37 one-way-ratchet feel. Risk lives in the vault/roof cover gauntlet (§5.2), which is **risky-but-fair** (movement solves it, ≥192u lanes, no forced camp) — a SKILL lever per docs/36, never a kill-box per docs/11.
- **Lab never sealed / both approaches built:** BOTH tunnels are enclosed + mazed identically; the randomizer (`_acc_map_randomizer::apply_pap_approach`) welds ONE via `acc_pap_block_*` per run. The geometry is static and valid for either weld state. The lab-side mouth stays open (the un-welded approach) → guaranteed ≥2 outs end-to-end; the welded-side maze simply sits behind a solid blocker (harmless).
- **Cut-vertex / ≥2-exits:** a corridor is not a zone; enclosing it does not reduce zone exits. The maze never spans the lane (no dead-end / soft-lock), preserving navmesh continuity.
- **Navmesh / Brutus:** ground-only zombies are unaffected by the ceiling; the room gauntlet keeps ≥192u so Brutus's straight charge (goalradius 64) can't wall-trap. Full `cod2map64` regen keeps the mesh valid.
- **First-room freedom:** the start-cover S0/S1 obstacles (already shipped) break the open spawn arena's "free training" pull without sealing it — consistent, and untouched by this work.

---

## 8. Step-by-step implementation plan + open questions

### Plan (when the editing agent releases the `.map`)

1. **Back up** the live `.map` (`…map.pre-tunnel-bak`). Working mode: edit-on-main, no commits.
2. **Re-verify literals** (a concurrent agent is editing): lab wall brushes 94/95/97/98 still z256; door slab z[0,128] + vector +130; PaP blockers z[0,256] at X[1040,1056]/[-1056,-1040]; probe boxes still malformed. (All confirmed as of this report.)
3. **Run the LED diagnosis (§6 step 0)** before authoring — establish whether flakiness or geometry is the cause.
4. **Fix the 7 malformed reflection-probe boxes** (size_min ≤ size_max each axis); resize to the shrunk rooms. Rebuild once to confirm this alone doesn't change LED behavior.
5. **Author both tunnels** as one-box tubes (§3.2), resolve the door clearance (§3.4), add per-tunnel light (§4.1) + probe (§4.2).
6. **Build via full pipeline** (§6) and confirm a REAL relight + lit tunnel + valid navmesh + working door + reachable approaches.
7. **Add the vault/roof cover gauntlet** (§5.2); rebuild; verify pathing.
8. **Playtest-tune** light color/intensity and cover density (ship conservative — single chicane — behind a dev gate, tune up).

### What to verify at build time (must-confirm)

- **O-1 (load-bearing):** Does a cleanly-authored one-box tube with a **z256 flush ceiling-on-walls** LED-bake on this install, or must the ceiling be offset to z260? The repo never ran this controlled test. Build ONE minimal tube headless to settle it. Also confirm the 2026-06-13 doorway-cut bake was genuinely clean (fresh `.led` mtime) before treating it as proof.
- **O-2:** Door clearance — does the z258-open slab clear the chosen ceiling? Recess pocket vs re-spec the +130 slide vs z260 cap (§3.4). Confirm the open state reads correctly in-game.
- **O-3:** Do `light` entities require a `.zone` manifest line on this install? (Likely no — worldspawn-baked — but the map has zero precedent.)
- **O-4:** Does the GUI bake + Launcher light-compile actually succeed on this split install where headless crashes? The Launcher Run path is documented broken — verify before relying on the GUI fallback.
- **O-5:** Exact stock sky-portal material token if a sky-gap is ever chosen (unresolved; recommend not needed).

### Decisions for the user

1. **Construction:** one-box tube that replaces the open-top walls (safest, recommended) vs floating z260 cap over existing walls (fewer brushes, sliver risk). Recommend the one-box tube.
2. **Where the risk lives:** vault/roof cover gauntlet (recommended) vs in-corridor maze (NAVMESH dossier strongly advises against — the 216u lane is too tight).
3. **Door clearance resolution:** recess pocket vs re-spec the door slide vs z260 cap.
4. **Light look:** cool cyan (`0.6 0.8 1`) cyberpunk vs amber hazard — playtest-tune.

### Key evidence files
- `tools/apply_room_shrink.js:78-103` (disabled C*/M* coords + the LED-crash gotcha note).
- `CHANGELOG.md:143-163` (Stage-3 deferral + LED gotcha), `:9-24` (lockdown seal, 8u-inset, LED flaky non-fatal), `:186-210` (clean LED of gen_rooms shells).
- `map_source/zm/zm_abandoned_cyber_city.map`: brushes 94/95/97/98 (lab walls z256, lines 917-966); entity 101/103 (door slabs, lines 2408-2461); entity 104/105 (PaP blockers z256, lines 2463-2493); entities 115-121 (7 reflection probes, malformed box `size_min Y 548.5 > size_max Y 544.75`, lines 2621-2808); 0 `classname light`.
- `tmp/kelson8_testmap/map_source/zm_test_map.map:3792-3818` (verified PRIMARY_OMNI light block, radius 100 / stops 6 / spawnflags 82 / NO `def`).
- `tools/gen_rooms.js:26,30-60` (verbatim UV + proven `box()` 6-plane winding; note `t7_*` defaults at lines 65-68 are BLOCKED, never reached live faces).