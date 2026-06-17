# 42 — Cyber Round-Progress Ring — Implementation Dossier

**Status:** research complete. SHIPPED FORM = a top-right horizontal **bar**
(`CoD.AccRoundRing` in `acc_hud.lua`, built 2026-06-17), full at round start and
draining right-to-left as the round's zombies die, Ronan teal→magenta. The circular
**radial ring** below was the first attempt but the stock `hud_objective_circle_meter`
material draws in FULL SCREEN SPACE (it needs the `setShaderVector(1/2/3)` center/radius
components the shipped `challenge_control.lua` sets, not just comp 0) — kept here as the
**deferred upgrade** recipe. The GSC bridge/math (§2–4) is shared by both.

**Method:** produced by a 6-domain deep-research + adversarial-verify pass
(2026-06-17). Every fact below was read on disk (repo + `tmp/bo3_stock_ref` stock
mirror + shipped community usermaps `tmp/zm_building`, `tmp/zm_countryside`,
`tmp/zm_alien_isolation` + the Mod Tools install). 12 of 14 high-risk claims
**confirmed**, 2 **refuted** — both on the core math (§2), corrected here.
Per the `document-external-codebase-findings` convention this supersedes any
conflicting code stubs that used a high-water-mark denominator.

> Design locked earlier: smooth radial drain (not segmented); cyber/Ronan teal
> theme; **NOT** using the shield PNG art — the ring is a STOCK radial-meter
> material + tinted LUI primitives (zero new image assets).

---

## 1. Executive summary

- **Radial fill technique (PRIMARY):** a `LUI.UIImage` using stock image
  `uie_t7_hud_interact_meter_thick` + stock material `hud_objective_circle_meter`,
  with `setShaderVector(0, fill, 1, 1, 1)` where the **x slot of component 0** is
  the fill fraction `0..1`. This is a **shipped-active** pattern in `zm_building`
  (`challenge_control.lua`), needs **no zone line**, and no new art.
- **Data path:** one new `clientuimodel` int field `accRoundRing` (7 bits),
  registered lockstep in `_acc_lui.gsc` + `_acc_lui.csc`, pushed per-player by a
  watcher, read in Lua via `subscribeToModel`.
- **Theme:** teal fill `(0.25, 0.85, 0.80)` lerping toward magenta/red
  `(0.90, 0.20, 0.55)` as it empties; navy backer `(0, 0.035, 0.085)`; cyan accent
  `(0.20, 0.75, 1.0)` — all already used in `acc_hud.lua`.
- **Top residual risk:** the stock meter image/material are **not** present as
  loose source in the Mod Tools (they ship inside game fastfiles), so runtime
  loadability in our usermap can only be confirmed **in-game**. A shipped
  community usermap uses them, which is strong evidence — but §9 has a fallback
  ladder if they don't render.

---

## 2. The math (CORRECTED — two refutations applied)

**Numerator — "zombies remaining this round" (CONFIRMED):**

```
remaining = zombie_utility::get_current_zombie_count()   // alive on the field
          + level.zombie_total                           // still to spawn
```

`level.zombie_total` = "Total number of zombies left to spawn"
(`_zm.gsc:1167`), decremented per spawn (`_zm.gsc:3813`). The two terms are
**disjoint**, so the sum never double-counts. Stock's own round-over gate is
exactly this sum reaching zero:
`should_wait = ( get_current_zombie_count() > 0 || level.zombie_total > 0 || level.intermission )`
(`_zm.gsc:4733`). So `remaining` hits 0 precisely when the round ends — perfect
for a drain.

**Denominator — the round's "full" count (REFUTED → corrected):**

- ❌ **Do NOT** use `level.zombie_total` alone as the denominator — it is the
  spawn queue and drains to 0 mid-round while zombies are still alive
  (verdict 7).
- ❌ **Do NOT** latch a high-water-mark `peak = max(peak, remaining)` over ticks
  — `level.zombie_total` starts at its max and only decrements, so a max-latch
  never sees higher than the first read **and** mis-tracks overload/hack waves
  (verdict 12, explicitly "would actually be WRONG").
- ✅ **Capture the denominator ONCE** at round start. Verified safe: a GSC
  `thread` runs synchronously to its first `wait`, so `round_spawning()`
  assigns `level.zombie_total = get_zombie_count_for_round(...)` (`_zm.gsc:3717`,
  before the spawn loop at 3733) **before** `level notify("start_of_round")`
  (`_zm.gsc:4433`). Our `acc_round_start` is relayed off `start_of_round` the
  same frame (`_acc_main.gsc:253→260`). So at `acc_round_start`, `zombie_total`
  is already the full round count, **not** 0. (Corroborated by our own
  `VERIFIED(acc)` note at `_acc_boss.gsc:140-145`.)

```
round_total = level.zombie_total + get_current_zombie_count()   // captured once per round
fill_pct    = clamp( round( 100 * remaining / round_total ), 0, 100 )
```

**Edge cases (handled in §3 director):**
- **Overload / hack events** do `level.zombie_total += N` mid-round
  (`_acc_events_overload.gsc:330,343`, `_acc_events_hack.gsc:414`) → `remaining`
  can briefly exceed `round_total` → the `clamp ≤ 100` keeps the ring at full
  while the extra wave is cleared (ring "refills" then drains again). Acceptable.
- **Stuck-zombie failsafe** `zombie_total++` (`zombie_utility.gsc` re-queue path)
  → a +1 transient, negligible.
- **Boss rounds** force `level.zombie_total = 0` (`_acc_boss.gsc:165`) and bosses
  usually carry `ignore_enemy_count` (not in `get_current_zombie_count()`), so
  `remaining ≈ 0` from the start → a normal drain ring would read empty
  immediately. **Handled by hiding the ring on boss/no-wave rounds** (denominator
  `< 1` after a settle wait → push the hide sentinel; §3). Optional future polish:
  drive the ring off boss health instead.

---

## 3. GSC changes — `scripts/zm/zm_abandoned_cyber_city/_acc_lui.gsc`

### 3a. Add the `#using` for the zombie-count API
`zombie_utility::get_current_zombie_count()` is in
`scripts\shared\ai\zombie_utility.gsc` (`#namespace zombie_utility;` confirmed at
`zombie_utility.gsc:26`). Add with the other `#using` lines (BEFORE `#namespace`
at line 31 — directive-order rule):

```gsc
#using scripts\shared\ai\zombie_utility;
```

### 3b. Register the clientfield — append LAST, after line 67
Insert immediately **after** the `accPowerupMask` register (`_acc_lui.gsc:67`)
and **before** `callback::on_connect( &on_player_connect );` (line 68):

```gsc
    // Round-progress ring fill, top-right. 0..100 = visible fill % (full at round
    // start, drains to 0 as the round's zombies die); ACC_RING_HIDE (127) = hidden
    // (boss / no-wave rounds). 7 bits (0..127). Appended LAST so existing fields'
    // bit layout is untouched (MUST match _acc_lui.csc order/width). Driven by
    // round_ring_watch(); acc_hud.lua CoD.AccRoundRing draws the radial meter.
    clientfield::register( "clientuimodel", "accRoundRing", VERSION_SHIP, 7, "int" );
```

### 3c. Setter + hide sentinel — after `set_powerup_mask` (~line 121)

```gsc
// 0..100 = visible ring fill %, ACC_RING_HIDE = hidden (boss / no-wave rounds).
#define ACC_RING_HIDE 127

// Push the round-progress ring value (0..100 fill, or ACC_RING_HIDE to hide).
function set_round_ring( player, val )
{
    if ( !isdefined( val ) || val < 0 ) val = 0;
    if ( val > 127 ) val = 127;
    player clientfield::set_player_uimodel( "accRoundRing", val );
}
```

### 3d. The level "director" — owns the per-round denominator + hide flag
A single level thread (NOT per-player) captures `round_total` once per round and
decides whether the ring is shown. Polls `level.round_number` for change to
sidestep the missed-notify race (verdict 13) and to handle the boss-suppression
settle window. Add anywhere at file scope:

```gsc
// Owns the round-progress ring's per-round denominator + hide decision (one
// instance, level scope). Per-player watchers (round_ring_watch) read these.
// Captures round_total ONCE per round (NOT a high-water latch - see docs/42 §2).
function round_ring_director()
{
    level endon( "end_game" );

    level.acc_ring_denom = 1;
    level.acc_ring_hide  = true;   // hidden until the first round is captured

    last_round = -1;
    for ( ;; )
    {
        if ( isdefined( level.round_number ) && level.round_number != last_round )
        {
            last_round = level.round_number;
            level.acc_ring_hide = true;   // hide during the settle window
            wait 0.5;                     // let stock baseline zombie_total AND boss
                                          // suppression (_acc_boss zeroing) settle
            togo = ( ( isdefined( level.zombie_total ) && level.zombie_total > 0 ) ? level.zombie_total : 0 );
            total = togo + zombie_utility::get_current_zombie_count();
            if ( total < 1 )
            {
                level.acc_ring_hide = true;    // boss / no-wave round -> stay hidden
            }
            else
            {
                level.acc_ring_denom = total;  // captured ONCE = the "full" ring
                level.acc_ring_hide  = false;
            }
        }
        wait 0.1;
    }
}
```

### 3e. The per-player watcher — pushes fill on change
Per-player (matches every existing watcher; handles late-join; per-player
change-detection — verdicts 4 & 11). Reads the level-owned denominator so a
late-joiner's ring is correct. Add at file scope:

```gsc
// Per-player loop: push the round-progress ring fill (0..100, or ACC_RING_HIDE)
// to the LUI overlay. remaining = alive + still-to-spawn, over the level-owned
// per-round denominator. 0.25s poll + push-on-change (Lua tweens between pushes).
function round_ring_watch()
{
    self endon( "disconnect" );
    level endon( "end_game" );

    last_val = -1;
    for ( ;; )
    {
        wait 0.25;

        if ( !isdefined( level.acc_ring_hide ) || level.acc_ring_hide )
        {
            val = ACC_RING_HIDE;
        }
        else
        {
            alive = zombie_utility::get_current_zombie_count();
            togo  = ( ( isdefined( level.zombie_total ) && level.zombie_total > 0 ) ? level.zombie_total : 0 );
            remaining = alive + togo;
            denom = ( ( isdefined( level.acc_ring_denom ) && level.acc_ring_denom > 0 ) ? level.acc_ring_denom : 1 );
            val = Int( ( remaining * 100 ) / denom );
            if ( val < 0 ) val = 0;
            if ( val > 100 ) val = 100;   // clamp overload/hack overshoot to full
        }

        if ( val != last_val )
        {
            set_round_ring( self, val );
            last_val = val;
        }
    }
}
```

### 3f. Start both threads in `player_lui_init` (after line 148)
Add after `self thread pickup_flash_watch();` (line 148). The director is started
once, guarded:

```gsc
    // Round-progress ring (top-right). The director (level scope) is started once;
    // each player gets a watcher that reads its per-round denominator.
    if ( !isdefined( level.acc_ring_director_started ) )
    {
        level.acc_ring_director_started = true;
        level thread round_ring_director();
    }
    self thread round_ring_watch();
```

> GSC gotchas honored above: ternaries are **fully paren-wrapped**
> `( ( cond ) ? a : b )`; `#namespace` stays after all `#using`/`#insert`;
> `Int()` is the cast. `round_ring_director` polls (never `flag::wait_till`),
> so it is safe even though it is a level thread.

---

## 4. CSC changes — `scripts/zm/zm_abandoned_cyber_city/_acc_lui.csc`

Append the mirror register **after** the `accPowerupMask` line (`_acc_lui.csc:38`),
as the last line before the closing brace (line 39). SAME name/version/bits/type/
order as the `.gsc` — a mismatch corrupts the field and hangs load:

```gsc
    clientfield::register( "clientuimodel", "accRoundRing", VERSION_SHIP, 7, "int", undefined, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
```

No other `.csc` change: the entry `zm_abandoned_cyber_city.csc:63` already
`LuiLoad("ui.uieditor.menus.hud.acc_hud")`, and `clientuimodel` auto-pipes to the
Lua model (no callback handler needed).

---

## 5. LUI changes — `ui/uieditor/menus/hud/acc_hud.lua`

Clone the `CoD.AccPowerupBar` widget shape (the cleanest template, lines 417-463
in the current file). Add a new `CoD.AccRoundRing` widget, then register it in
`LUI.createMenu.acc_hud` (lines 465-499) next to the others.

### 5a. Color-lerp helper (top of file, near `acc_bit_is_set` at line 327)

```lua
-- Round-ring color: teal (full) -> magenta/red (empty). t in 0..1 = emptiness.
local ACC_RING_FULL  = { 0.25, 0.85, 0.80 }   -- teal/cyan glow
local ACC_RING_EMPTY = { 0.90, 0.20, 0.55 }   -- magenta/red
local function acc_ring_color(t)
    if t < 0 then t = 0 elseif t > 1 then t = 1 end
    return ACC_RING_FULL[1] + (ACC_RING_EMPTY[1] - ACC_RING_FULL[1]) * t,
           ACC_RING_FULL[2] + (ACC_RING_EMPTY[2] - ACC_RING_FULL[2]) * t,
           ACC_RING_FULL[3] + (ACC_RING_EMPTY[3] - ACC_RING_FULL[3]) * t
end
```

### 5b. The widget (verified API only; placeholders marked)

```lua
-- TOUCHPOINT 5 - Cyber round-progress ring (top-right). Smooth radial drain via the
-- stock uie_t7_hud_interact_meter_thick image + hud_objective_circle_meter material
-- (setShaderVector component 0 .x = fill 0..1), the shipped-active zm_building
-- challenge_control.lua recipe. Driven by the "accRoundRing" clientuimodel int
-- (0..100 = fill %, 127 = hide). No new art, no zone line. docs/42, docs/28.
CoD.AccRoundRing = InheritFrom(LUI.UIElement)

function CoD.AccRoundRing.new(HudRef, InstanceRef)
    local self = LUI.UIElement.new()
    self:setClass(CoD.AccRoundRing)
    self.id = "AccRoundRing"

    -- TOP-RIGHT anchor. setLeftRight(anchorLeft, anchorRight, leftPx, rightPx):
    -- right-anchored, offsets negative = inward. setTopBottom top-anchored, positive
    -- = down from the top edge. SIZE x SIZE box, MARGIN px in from top & right. TUNE.
    local SIZE   = 64
    local MARGIN = 28
    self:setLeftRight(false, true, -(MARGIN + SIZE), -MARGIN)
    self:setTopBottom(true, false,   MARGIN,          MARGIN + SIZE)

    -- Backer ring: always full, dim navy (reads the empty arc as a track).
    local Backer = LUI.UIImage.new()
    Backer:setLeftRight(true, true, 0, 0)
    Backer:setTopBottom(true, true, 0, 0)
    Backer:setImage(RegisterImage("uie_t7_hud_interact_meter_thick"))
    Backer:setMaterial(RegisterMaterial("hud_objective_circle_meter"))
    Backer:setShaderVector(0, 1, 1, 1, 1)         -- full ring
    Backer:setRGB(0, 0.035, 0.085)                -- navy
    Backer:setAlpha(0.45)
    self:addElement(Backer)                       -- added first = behind

    -- Fill ring: drains; teal -> magenta as it empties.
    local Fill = LUI.UIImage.new()
    Fill:setLeftRight(true, true, 0, 0)
    Fill:setTopBottom(true, true, 0, 0)
    Fill:setImage(RegisterImage("uie_t7_hud_interact_meter_thick"))
    Fill:setMaterial(RegisterMaterial("hud_objective_circle_meter"))
    Fill:setShaderVector(0, 1, 1, 1, 1)           -- start full
    Fill:setRGB(ACC_RING_FULL[1], ACC_RING_FULL[2], ACC_RING_FULL[3])
    Fill:setAlpha(0.95)
    self:addElement(Fill)                         -- added later = on top
    self.Fill = Fill

    -- Subscribe: 0..100 -> 0..1 fill; >100 (ACC_RING_HIDE) hides the whole widget.
    self:subscribeToModel(Engine.GetModel(Engine.GetModelForController(InstanceRef), "accRoundRing"), function(m)
        local v = Engine.GetModelValue(m) or 127
        if v > 100 then
            self:hide()
            return
        end
        self:show()
        local frac = v / 100
        self.Fill:completeAnimation()
        self.Fill:beginAnimation("keyframe", 250, false, false, CoD.TweenType.Linear)
        self.Fill:setShaderVector(0, frac, 1, 1, 1)        -- radial drain (full->empty)
        self.Fill:setRGB(acc_ring_color(1 - frac))         -- teal (full) -> magenta (empty)
    end)

    self:hide()   -- hidden until the server pushes a visible fill
    return self
end
```

### 5c. Register in `LUI.createMenu.acc_hud` (alongside the other widgets)

```lua
    local RoundRing = CoD.AccRoundRing.new(Hud, Instance)
    Hud:addElement(RoundRing)
    Hud.accRoundRing = RoundRing
```

(No `close` override needed — `AccRoundRing` holds no child menu, unlike
`AccPerkCard`.)

---

## 6. Theme execution (no new art)

| Token | RGB | Use |
|---|---|---|
| Teal fill | `0.25, 0.85, 0.80` | live ring (full) |
| Magenta/red | `0.90, 0.20, 0.55` | live ring (empty), lerp target |
| Navy backer | `0.00, 0.035, 0.085` | track ring (already `acc_hud.lua:115`) |
| Cyan accent | `0.20, 0.75, 1.0` | optional ticks/echo (already `acc_hud.lua:124`) |

- **Color lerp:** `setRGB` composes with `setShaderVector(fill)` on the same image
  — verified: `challenge_control.lua` tints the same meter image gray (backer) and
  gold (progress). So §5a's lerp on the Fill ring each update is sound.
- **Optional glitch-chrome RGB-split echo (deferred polish):** add the same meter
  ring twice more behind `Fill`, offset ±2px, low-alpha cyan and magenta, sharing
  the same `setShaderVector(0, frac, ...)`. Adds the Ronan "chromatic aberration"
  edge. Skip for v1; the teal→magenta lerp already reads as cyber.
- **Solid tinted primitives** (if you later add corner ticks): use
  `CoD.TextWithBg` with empty text and `.Bg:setRGB/.Bg:setAlpha` (proven in
  `acc_hud.lua:111-126` AND shipped `blackscreen.lua`). Do **NOT** use `Hud.Bg`
  (the menu root has no `.Bg` → UI Error 43408).

---

## 7. Zone / assets

- **No zone change.** The meter image `uie_t7_hud_interact_meter_thick` and
  material `hud_objective_circle_meter` resolve from stock fastfiles —
  `zm_building.zone` uses both with **no** `image,`/`material,` line. `acc_hud.lua`
  is already `rawfile,...` (`zm_abandoned_cyber_city.zone:150`), and both LUI
  modules are already `scriptparsetree`.
- **Only** add an `image,<name>` line if a fallback (§9) uses a non-core ring
  sprite (e.g. `uie_t7_zm_hud_revive_ringtop`) — the bbgum precedent shows those
  get listed (`zm_building.zone:295-298`).

---

## 8. Build & test

This change touches GSC + CSC + the `acc_hud.lua` **rawfile** — **no geometry**.
`-GscOnly` is correct and sufficient (CONFIRMED): it skips only cod2map64+LED; the
linker always runs and re-reads the **whole** `.zone`, repacking the rawfile and
`.csc` into the `.ff`.

```powershell
.\tools\build_map.ps1 -GscOnly          # sync -> linker -> fresh-.ff check
# or build + launch in one shot:
.\tools\build_map.ps1 -GscOnly -Run
```

- **Sync is automatic** inside `build_map.ps1` (the linker builds the DEPLOYED
  usermap copy, not the repo).
- **Success = a FRESH `.ff`** at
  `<tools>\usermaps\zm_abandoned_cyber_city\zone\zm_abandoned_cyber_city.ff`
  (timestamp advanced) — **not** the linker exit code.
- **L3akMod** (the `libtiff64r.dll` swap that lets the linker compile a
  `rawfile,*.lua`) is installed + verified live; no action needed.
- **In-game test** (the user): `.\tools\run_game.ps1` (launches through Steam with
  `+set_gametype zclassic`; custom LUI runs with no special flag). Watch the
  **top-right** ring: full at round start, drains to empty as the last zombie
  dies, hidden on boss rounds. Lua **runtime** errors show as an on-screen
  `UI Error <code>` box (NOT in `console_mp.log`).

---

## 9. Top risks & mitigations (fallback ladder)

| # | Risk (from adversarial verify) | Verdict | Mitigation |
|---|---|---|---|
| R1 | `uie_t7_hud_interact_meter_thick` / `hud_objective_circle_meter` may not load at runtime in our usermap (not on disk as loose source; ship in fastfiles). | unverifiable offline; shipped usermap uses them = strong evidence | **In-game smoke test first.** If the ring is invisible / `UI Error`: drop to the ladder below. |
| R2 | Drain direction: `fill = remaining/total` may fill clockwise *up* instead of draining. | in-game only | If reversed, send/use `1 - frac` (or swap to `uie_clock_add`). One-line flip. |
| R3 | Boss-round hide relies on `round_total < 1` after a 0.5s settle; a race with `_acc_boss` zeroing `zombie_total` could mis-time. | logic sound, timing in-game | Confirm on an actual boss round (r3/r10/r20). If it flickers, gate on an explicit boss-active flag instead of the `< 1` heuristic. |
| R4 | `setShaderVector(0, frac, 1,1,1)` with a literal float (not a packed model-string). | likely fine | If the ring doesn't respond, use the `whoswhorevivewidget.lua:74` model-string + `CoD.GetVectorComponentFromString` path. |

**Radial-fill fallback ladder (theme survives all rungs):**
1. **PRIMARY** — `uie_t7_hud_interact_meter_thick` + `hud_objective_circle_meter`,
   `setShaderVector(0, frac, 1,1,1)`. (zm_building precedent.)
2. **`uie_clock_*` family** — `uie_clock_normal`/`uie_clock_add` on a ring image
   (`uie_t7_zm_hud_revive_ringtop`, add an `image,` zone line), with
   `setShaderVector(1,0.5)(2,0.5)(3,0.08)` for center/thickness and index 0 driven
   by `frac`. Both `.techsetdef`s are **on disk**
   (`share/raw/techsetdefs_stable/2d/uie_clock_*.techsetdef`); used by shipped
   `zm_countryside`. (bbgum-meter recipe, verified.)
3. **Two rotating half-rings** — `setZRot(deg)` on overlay arcs (also verified in
   `zm_countryside`).
4. **Themed vertical/arc bar** — last resort; same teal→magenta skin.

---

## 10. Seamless implementation checklist (ordered)

1. `_acc_lui.gsc` — add `#using scripts\shared\ai\zombie_utility;` (with the other
   usings, before `#namespace`, line ~22).
2. `_acc_lui.gsc` — append the `accRoundRing` register after line 67 (§3b).
3. `_acc_lui.gsc` — add `#define ACC_RING_HIDE 127` + `set_round_ring()` after
   `set_powerup_mask` (~line 121) (§3c).
4. `_acc_lui.gsc` — add `round_ring_director()` (§3d) and `round_ring_watch()`
   (§3e) at file scope.
5. `_acc_lui.gsc` — in `player_lui_init`, after line 148, start the guarded
   director + the per-player watcher (§3f).
6. `_acc_lui.csc` — append the mirror `accRoundRing` register after line 38 (§4).
7. `acc_hud.lua` — add `acc_ring_color` helper (§5a), the `CoD.AccRoundRing`
   widget (§5b), and register it in `LUI.createMenu.acc_hud` (§5c).
8. Build: `.\tools\build_map.ps1 -GscOnly`; confirm a fresh `.ff`.
9. User test in-game: ring full at round start → drains to 0 at round end →
   hidden on boss rounds. Tune `SIZE`/`MARGIN` and verify drain direction (R2).
10. CHANGELOG.md + docs/28 (or this doc) updated in the same commit.

---

### Appendix — key verified citations
- Radial recipe + shipped-active: `tmp/zm_building/ui/uieditor/menus/hud/challenge_control.lua:39-49, 455`; referenced by `inventory_control.lua:1,103`; `zm_building.zone:274`.
- 2nd precedent: `tmp/zm_countryside/.../whoswho/whoswhorevivewidget.lua:64-74` (`uie_clock_add`, `setZRot`).
- Materials on disk: `<tools>/share/raw/techsetdefs_stable/2d/uie_clock_{normal,add,multiply}.techsetdef`.
- Counts: `tmp/bo3_stock_ref/scripts/shared/ai/zombie_utility.gsc:2017,2023,2031` (`get_current_zombie_count`/`get_round_enemy_array`/`ignore_enemy_count`); `_zm.gsc:1167,3717,3813,4733`.
- Round dispatch: `_acc_main.gsc:253-261` (`acc_round_start`); boss zeroing `_acc_boss.gsc:165`; overload/hack adds `_acc_events_overload.gsc:330,343`, `_acc_events_hack.gsc:414`.
- Bridge: `_acc_lui.gsc:35-77` (register block + `__init__`), `:117-126` (setter + on_connect), `:130-151` (`player_lui_init`); `_acc_lui.csc:28-39`; `version.gsh:36` (`VERSION_SHIP=1`), `:102-103` (`CF_*`).
- LUI API: `acc_hud.lua:111-126` (TextWithBg.Bg), `:327-329` (no-bitwise), `:417-499` (AccPowerupBar template + createMenu).
- Build: `tools/build_map.ps1:146,197,201-223`; `tools/sync_to_modtools.ps1:182-186`; L3akMod `docs/28_lui_pipeline.md:14-29`.
