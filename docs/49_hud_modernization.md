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
- **★ THE CLIENTFIELD POOL IS FULL — EMPIRICALLY CONFIRMED 2026-06-28** (`_acc_lui.gsc:44-80`): **66 bits
  across 8 clientuimodel fields** (the older "~73 bits / 9 fields" figure was stale — recounted 2026-06-28).
  Adding a wider field overflows the shared zombies pool and breaks a STOCK field (`zmhud.swordEnergy`) →
  `Com_ERROR` at load. **PROVEN by a throwaway probe:** a registered-but-unused **24-bit** `accProbe24`
  clientuimodel field **failed to load (Com_ERROR)** → **headroom is < 24 bits.** Consequences for HUD work:
  - **The full LUI HUD migration is BLOCKED** — it needs ~50 new bits (audit 2026-06-28); they do not exist.
  - **Even a 24-bit packed co-op-roster field does NOT fit.** A ~11-bit health-only roster field is **untested
    and right at the cliff edge** (fragile — one stock update or field add re-breaks it); not recommended.
  - **The co-op SERVER-HUDELEM pool fix must be GSC-side** (roster trim / flash-on-buy announcements /
    destroy-on-hide), NOT a clientfield→LUI roster. See the 2026-06-28 hudelem-budget audit.
  - Only **~4 bits are reclaimable in code** (narrow `accDmgNum` 18→14 by capping the displayed damage number);
    not enough for a roster field on its own.
  **Any "just append one field" plan is budget-BLOCKED.** Most "new field" needs can be avoided (see principles).

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
6. **NEVER `SetText` a live/unbounded number on a server hudelem — use `SetValue`.** A second scarce
   resource (separate from the clientfield pool): the engine **`string` BG-cache, cap 2048 per match**,
   fed by every DISTINCT string passed to a hudelem `SetText`; each one **permanently burns a slot**
   (never freed) → `BG_Cache_GetIndexInternal - Exceeded '2048' items for type 'string'` CTD. A number
   via **`SetValue` costs ZERO slots** (stock `_zm.gsc` `countdown_hud SetValue`). So: numbers that vary
   widely over a match (score/points, shard count, accumulating kill counters) **must** be `SetValue`;
   `SetText` is only for **constant** or **small bounded** strings (and change-guard those too). Gotchas:
   `alpha = 0` (hidden) does **NOT** prevent registration — it happens on the `SetText` *call*; the merged
   "label + N numbers" line is a trap (its distinct-string count is the *product* of the numbers' ranges).
   **To keep a text PREFIX on a crash-safe number and render flush, use two elements:** a `SetText` element
   holding the bounded text + the literal prefix char (e.g. `"… EXO 6  $"`), **right-aligned** so its right
   edge is fixed, and a `SetValue` number element **left-aligned 2px after** it → `…$12500` renders flush
   every frame regardless of digit count, and the unbounded number stays out of the string cache. **Do NOT
   use the hudelem `.label` field** — verified in-game 2026-06-26 it does **not draw** on
   `hud::createFontString` server hudelems (only the bare `SetValue` number rendered, the whole `.label`
   prefix vanished); it likely needs a localized istring, which you can't build from a live value. Keep the
   small *bounded* numbers (shards 0-~hundreds, tier 0-10, count 0-25) in the `SetText` half — only the
   *runaway* field (score, accumulating timer) needs `SetValue`. (SERVER-side twin of the `triggerstring`
   250-cap `SetHintString` rule — memories `string-cache-setvalue-not-settext` + `triggerstring-cap-hint-strings`.
   Fixed the co-op roster `$points` overflow, 2026-06-26.)

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

## Custom combat HUD (the stock ammo/weapon reskin) — addendum 2026-06-26

Separate from the Phase roadmap above, the user asked to replace the **stock bottom-right ammo/weapon/grenade block** (which
the original plan left as stock). Feasibility study (6-agent workflow) + build landed the same day. Key facts (full detail in
memory `hud-combat-reskin-client-models`):
- **Track A wins:** draw our own widgets in the safe `acc_hud` overlay + suppress the stock block. Track B (override
  `T7Hud_zm_factory`) is the non-loadable-`.ff` trap (`lui-menu-can-break-map-load`) — rejected.
- **Zero new clientfields:** ammo/reserve/name/lethal/tactical are engine client-side UIModels (`CurrentWeapon.*`,
  `CurrentPrimaryOffhand/SecondaryOffhand.*`), a *separate* namespace from the full clientuimodel pool. Bindings copied from
  on-disk `zm_building` `zmammo_*_abbey.lua`, recolored to `ACC_PAL` (no custom font, no custom material).
- **Suppression:** `SetClientUIVisibilityFlag("weapon_hud_visible", 0)` clears `BIT_WEAPON_HUD_VISIBLE` (gates the whole stock
  block), re-asserted 0.25s. **Phase 0 in-game gate:** prove the hide before trusting the reskin (may also hide d-pad/GobbleGum).
- **BLOCKED — bottom-left team health:** there is NO player-health LUI model anywhere in stock; own-health needs a new field
  (pool full) — workaround = restyle the GSC health bar (`_acc_health_bars.gsc:73-118`); live teammate health is multi-field,
  deferred behind a bit-budget audit; teammate avatars are engine-owned (omit).
- **BUILT 2026-06-26** (`-GscOnly`, BUILD OK, awaiting in-game verify): `suppress_stock_weapon_hud` (Phase 0) +
  `CoD.AccAmmoBlock`/`CoD.AccEquip` (Phase 1, TOUCHPOINT 7 in acc_hud.lua). Next: in-game verify hide + positions; then
  per-gun silhouette art + own-health bottom-left restyle.

## Status
**Phase 1 batch 1 BUILT 2026-06-22** (`-GscOnly`, BUILD OK, awaiting in-game verify): shared `ACC_PAL`
palette; perk-icon overlap fix (PITCH 48); damage-number rise+fade; ~~Overclock glass chip~~ (REVERTED
2026-06-22 — user wanted plain `vN` text; the glass plate + cyan keyline were removed, bare teal text
kept); info-card bottom accent strip. All in `acc_hud.lua`, proven primitives only, self-contained per widget.

**SUPERSEDED IN LARGE PART 2026-07-03 — AETHERIUM HUD ADOPTED** (CHANGELOG entry + docs/22). The
Owen-C137 kit replaced the stock HUD wholesale (T7Hud_zm_factory redefinition), which resolves several
of this doc's blockers by a different route than planned:
- **Custom fonts: UNBLOCKED** — the kit ships the proven path (`ttf,` zone lines + `setTTF`). The
  "biggest cheap tell" is gone.
- **"Two clashing render systems": largely gone** — the roster/round-counter GSC hudelem wall is retired
  (behind `level.acc_aetherium_hud`); only the compact own-stats block (2 hudelems), boss bar, and
  event/announce hudelems remain server-side.
- **The clientuimodel-pool blocker is ROUTED AROUND, not lifted** — the kit's player-health/state fields
  ride the near-empty **world scope** (player_health_0..3 = 28 bits + 8-bit packed states). The
  clientuimodel pool itself is STILL full; principles 1/2/6 all still apply to any new field.
- Our kept uniques (info card, damage numbers, HOSTILES bar, PaP/OC chips, shard icon) still live in the
  slim acc_hud overlay — Phase-1-remainder polish (info-card slide-in, ring danger glitch) still applies
  to THEM. The retheme direction changes: recolor the AETHERIUM plates (kit ships blue/green/grey/orange/
  red/yellow variants under `sat_hud_colors/`, swap the 4 theme PNGs) toward our teal/magenta identity
  instead of building our own panel kit from rects.
