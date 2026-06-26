# 49 — HUD Modernization Plan ("One Salvaged Neural HUD")

Research-backed plan (2026-06-21, 6-agent workflow) to make the HUD best-in-class for custom BO3
zombies. **No code shipped yet — this is the roadmap.** Pipeline reference: docs/28_lui_pipeline.md.

## North star
A single dark-glass cyberpunk **device** — one palette, one motion grammar, one frame kit — wrapping a
clean combat center. **teal = power, magenta = danger** (lerps in as "decay"), and **only state CHANGES
animate**. Premium = *consistency + restraint + motion*, NOT complexity (the BO7 "Aetherium" lesson: one
themed accent layer over a clean base, decoupled so the accent hue is one variable). We already speak
this dialect (navy glass cards @0.82α, cyan top-accent, corner brackets, teal→magenta drain bar) — the
job is to **formalize it into one kit and apply it everywhere**.

## Honest current state
- **Strong (keep):** the LUI cyber icons — perk badges, power-up icons, PaP tier shields (Ronan's
  Cyberpunk Shaders, teal/magenta/red hex art). Every element's data pipeline (clientfield→uimodel→Lua)
  is sound and **reusable** — this is a presentation-layer job, not a re-plumb.
- **Weak (the "cheap" tells):** (1) **no custom font** — all text is the generic BO3 UI font (biggest
  tell); (2) **two clashing render systems** — slick LUI hex art vs. a wall of stock-engine GSC bars +
  `^N`-colored text (health bar, boss bar, the whole left-side Data Shards/Mega Bottles/web/items/gas
  stack) that looks like debug output; (3) **almost no state-change animation** (hard show/hide);
  (4) inconsistent treatment of adjacent stats (PaP = art, Overclock = bare `vN` text); (5) perk icons
  overlap (PITCH 38 < SIZE 44), unframed; (6) power-ups have **no countdown timer**; (7) the
  "teal round counter" docs/14 claims is **not actually shipped** (stock dark-red still); (8) QA zombie
  wallhack markers are **hardcoded ON** (must remove before ship).

## Hard constraints (what the LUI pipeline can/can't do)
**Feasible (proven in-repo):** keyframe tweens (`beginAnimation`/`completeAnimation` → fade/slide/scale/
color-lerp), plain images (`setImage(RegisterImage(...))`), dynamic `UIText`, solid rect shapes/frames/
bars (the `CoD.TextWithBg.Bg` primitive), stock element effects (`flicker`/`spinRandomly`/`playSound` —
**currently unused, free juice**), the GSC→clientfield→LUI bridge, suppressing stock widgets via their
uimodel, standalone additive overlay (`OpenLUIMenu('acc_hud')` — **safe**, can't break stock HUD).

**Blocked / high-risk — do NOT plan around these:**
- **Real full-screen shaders** (blur, true scanline/CRT, chromatic aberration, bloom) — that's engine
  postfx/`.vision`, not LUI. Fake with offset/low-alpha layers only; **be honest it's a fake.**
- **Custom materials (techset)** — headless shader-compile is blocked (docs/29 §14); use plain images.
- **Custom fonts** — no proven shipped path; unverified/high-risk. Treat as not-feasible without R&D.
- **Overriding stock HUD menus** (`t7hud_zm_custom`, `RoundStatus.lua`, `Intermission_Main`) — can BUILD
  OK yet make a **non-loadable `.ff`** (memory `lui-menu-can-break-map-load`). Overlays safe; menus risky.
- **★ THE CLIENTFIELD POOL IS NEARLY FULL** (`_acc_lui.gsc:73-78`): ~73 bits across 9 fields; adding a
  wider field overflows the shared zombies pool and breaks a STOCK field (`zmhud.swordEnergy`) →
  `Com_ERROR` at load. **Any "just append one field" plan is budget-BLOCKED until a real bit-budget
  audit proves headroom.** Most "new field" needs can be avoided (see principles).

## Principles to bake in (from the adversarial review)
1. **Measure before adding clientfields.** Audit remaining pool bits first; treat them as one shared
   scarce resource the new-field features compete for.
2. **Prefer client-side state over new fields:** power-up countdowns tween locally from known stock
   durations on the mask bit flipping 0→1 (no field); round number is engine state (`level.round_number`,
   already read client-side) — don't spend a field on it; **bit-pack** low-range counts (shards 0-63 +
   bottles 0-7 in 9 bits); **reuse retired slots** (the way `accOcTier` reused the dead `accLuiTest`).
3. **Refactor one widget at a time + in-game verify each** — LUI runtime errors show ONLY as an on-screen
   `UI Error <code>` box (never console). A nil in a *shared* helper blanks ALL 7 widgets, so keep the
   old path until each is proven; bisect per-widget.
4. **Gate entrance animations on a visibility STATE edge** (was-hidden→shown), not on every model push —
   else the info card re-slides every time PaP/OC ticks while it's up.
5. **Dark backing pills/plates aid contrast** against our intentionally dark map (color grade is OFF) —
   a real readability win, not just decoration.

## Phased roadmap

**Phase 0 — cleanup (do immediately):** remove the hardcoded QA wallhack markers (in `_acc_dev.gsc`/a
debug draw — grep to locate; not in the LUI); default the self health bar OFF (declutter).

**Phase 1 — the 80/20 (zero assets, zero new fields, `-GscOnly`, all in `acc_hud.lua`):** this delivers
most of the premium jump first.
1. **Shared palette + panel-kit module** — one `ACC_PAL` color table + helpers `make_plate`,
   `add_accent_strip`, `add_corner_brackets`, `add_scanlines` (3-4 low-alpha rects, NOT a CRT texture),
   `add_halo`; re-route every widget. (impact high / effort low / safe — *refactor one widget at a time*.)
2. **Info card → glass card** — brackets + ease-out slide+fade entrance on the hidden→shown edge.
3. **Damage number juice** — `completeAnimation()` then scale-pop 1.0→1.15→1.0 + upward drift before the
   existing 350ms fade + a dark backing pill (child `CoD.TextWithBg.Bg`, never `Hud.Bg` → UI Error 43408).
4. **Perk-bar rail** — PITCH ≥ SIZE (fix overlap) + shared glass rail + animate ONLY the newly-gained
   icon (slide-in/scale-pop) + `flicker()` on Mega.
5. **Overclock plate** — wrap the bare `vN` text in the same glass mini-plate as the PaP shield.
6. **Round-ring danger glitch** — brief `setLeftRight` jitter + `flicker()` + a 2-layer magenta offset
   "channel-split" *fake*, latched once per danger-crossing (reset each round).
7. **Free juice:** add `playSound`/`flicker`/`spinRandomly` punctuation on pickups/Mega (no asset/field).

**Phase 2 — motion + theme depth (gated on a bit-budget audit; favor client-side):**
- **Power-up countdown rings** — drive **client-side** from known stock durations (no new field) + an
  entrance flash; visually separate the 3s-blink instant power-ups from the persistent timed ones.
- **Glass event banners** for Lockdown / Reactor Surge / Glitch Altar — standalone overlay widget
  (safe); needs ~2-3 bits for an event id — the **cheapest** new-field ask; only if the audit allows.

**Phase 3 — the big unification (needs GDT asset work + measured bit budget):**
- **Migrate the GSC currency/inventory stack into LUI** with neon shard/flask icons — the single biggest
  cohesion win and biggest effort. Bit-pack counts into ONE field or reuse a retired slot; author 2-4
  icons into `acc_perk_shaders.gdt` (deploy via `tools/deploy_perk_shaders.ps1`). Validate the GDT/icon
  path independently of the data migration.
- **Health/boss bar:** Phase-1-style in-place GSC restyle (danger lerp + notches + default-off) is the
  realistic win; full LUI migration is budget-blocked pending the audit.

**Phase 4 — risky, last:** the teal round counter. Do NOT override stock `RoundStatus.lua`. Read
`level.round_number` client-side and either layer a teal numeral OVER the stock one or cosmetically
suppress the stock one (verify the round-up roll still plays). No new field.

## Status
**Phase 1 batch 1 BUILT 2026-06-22** (`-GscOnly`, BUILD OK, awaiting in-game verify): shared `ACC_PAL`
palette; perk-icon overlap fix (PITCH 48); damage-number rise+fade; ~~Overclock glass chip~~ (REVERTED
2026-06-22 — user wanted plain `vN` text; the glass plate + cyan keyline were removed, bare teal text
kept); info-card bottom accent strip. All in `acc_hud.lua`, proven primitives only, self-contained per widget.
**Next (Phase 1 remainder):** info-card slide-in (edge-gated), perk gain-pop / Mega flash, round-ring
danger glitch. **Phases 2-3** still begin with a **clientfield bit-budget audit** (the gating unknown).
