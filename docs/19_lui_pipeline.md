# 19 — LUI (Lua) client pipeline

The client-side UI layer: custom LUI HUD widgets driven by GSC. This is the
substrate every premium-UI touchpoint rides on — the perk-icon glow, the
perk/PaP info card, live counters (Data Shards / Mega Bottles / Exo tier),
crosshair damage numbers, the HOSTILES threat bar, and the unified gun-badge
chip row. Server-HUD cards (`_acc_ui.gsc` / `_acc_health_bars.gsc`, docs/11)
remain the all-GSC layer for anything cheaper to draw server-side; LUI is the
ceiling.

Status: **SHIPPED.** L3akMod is installed and the custom LUI is baked into the
`.ff` (first clean compile 2026-06-12; L3akMod verified live 2026-06-13). Since
2026-07-03 the **Aetherium HUD kit is the base HUD** (option A below) and our
uniques live in a slim additive `acc_hud` overlay (option B) on top of it. There
is no "test banner" anymore — the overlay carries real widgets (see below).

## HARD REQUIREMENT — L3akMod (build); NO runtime flag on Steam

The public BO3 mod tools linker **cannot compile a `rawfile,*.lua` source file** —
it errors `ERROR: Lua not supported`. Custom LUI needs **L3akMod** (DTZxPorter):

1. **Build time:** overwrite `<bo3_root>\bin\libtiff64r.dll` with the L3akMod
   **v1.0.4** build (https://dtzxporter.com/tools/l3akmod). Prereqs: VS2013 **and**
   VS2015 x64 runtimes (both verified present on this box). The original DLL is
   backed up at `bin\libtiff64r.dll.acc-orig-backup` (sha256 `9813F88B…589B63D9`,
   441856 bytes) — restore it to uninstall.
   - Alternative: pre-compiled `*.luac` can be linked without L3akMod, but
     producing T7/HavokScript-compatible bytecode itself needs L3akMod's compiler,
     so the DLL swap is the practical path.
   - **CREDIT (required by L3akMod's license):** the **D3V Team** must be credited
     for L3akMod use — add them to the map's in-game/Workshop credits (CREDITS.md).
   - Installed + verified live 2026-06-13 (linker prints
     `[L3akMod (D3V)] (v1.0.4) ... loaded successfully!`; build exit 0, the
     `Lua not supported` error gone).
2. **Runtime: NO launch flag needed on Steam BO3** (verified live 2026-06-13). Our
   menu executed in-game and a Lua bug in it threw **UI Error 43408** — which proves
   the custom Lua RAN (it was not sandbox-blocked). The community **`-unsafe-lua`**
   arg is a **BOIII-client** flag, not a Steam BO3 one: on Steam it logs
   `Unknown command "-unsafe-lua"` and does nothing. It is intentionally NOT passed
   by the launchers. (So the old "players need -unsafe-lua" ship-blocker is moot for
   Steam — the compiled LUI is baked into the `.ff`.)

## BUILD GOTCHA: L3akMod rejects non-whitelisted GLOBALS -> bogus `'ERR'` crash

**Hard-won 2026-07-11 (leaderboard Stage-0 spike, docs/40).** L3akMod's rawfile-Lua
compiler (the DLL that turns a `rawfile,*.lua` into HKS bytecode at LINK time) has a
**whitelist of allowed global identifiers**. Naming any global it doesn't know —
`io`, `os`, `_G`, `getfenv`, `loadstring`, `rawget` — **fails the compile**, and
because L3akMod's own error reporter is buggy the failure surfaces as the *misleading*:

```
[L3akMod (D3V)] Error: attempt to index global 'ERR' (a nil value)
```

…with linker **exit -1 and NO fresh `.ff`**. The `ERR` message is generic — it means
"a rawfile Lua chunk failed to compile," NOT anything about a literal `ERR` variable.
This is a **LINK-time** block, entirely separate from what the HKS **runtime** exposes.

- **Bisected live** (single-construct probe files, one global each): `type(pcall)`
  builds; `type(io)` does not. **Whitelisted (build OK):** `pcall`, `type`, `tostring`,
  `string.*`, `math.*`, `require`, **`load`**, `setfenv`, `Engine.*`/`LUI.*`/`CoD.*`.
  **NOT whitelisted (build CRASH):** `io`, `os`, `_G`, `getfenv`, `loadstring`,
  `rawget`/`select`. Plain **string literals** containing "io"/"os" are fine — only a
  bare non-whitelisted **global identifier** trips it.
- **THE DODGE (proven to compile + the pattern the spike ships):** reach a blocked
  global through **`load("… io …")`** — a string chunk the HKS VM compiles at RUNTIME,
  so the LINK-time whitelist never sees the identifier. `load` is whitelisted; the
  string is just data. Both `load("return io")` and the 5.1 `load(readerfn)` form
  build clean. (`.luac` precompiled bytecode is the other bypass — it skips L3akMod's
  source compiler entirely; likely how MACHIN[A] ships its `io`/`os` save system.)
- **Diagnosis method that worked:** run `linker_modtools.exe -language english
  -modsource <map>` directly (cwd = `bin`), capture stderr; `ERR` + exit -1 = a Lua
  rawfile is naming a blocked global. A/B by commenting `rawfile,` lines in the
  DEPLOYED `.zone` and relinking (linker-only, ~15-40s each) until the offending file
  is isolated, then bisect the constructs inside it.

## RUNTIME GOTCHA: `Hud.Bg` -> UI Error 43408

`CoD.Menu.NewForUIEditor()` does **not** expose a `.Bg` member. `Hud.Bg:setAlpha(..)`
indexes nil and throws **UI Error 43408** at runtime (it compiles fine — rawfile Lua
errors only surface at load, never at link). The commented-out `audiolog.lua` used
`Hud.Bg`; the only shipped-ACTIVE standalone overlay (`blackscreen.lua`) never does.
**Lesson: only copy from shipped-ACTIVE files, not commented-out ones**, and treat
the linker passing as proof of *syntax* only, never of runtime API validity. The
runtime oracle for LUI errors is the on-screen `UI Error <code>` box (the code is
generic "a Lua error occurred in the UI"; the traceback is not in console_mp.log).
For a dark backing behind a widget, use the `CoD.TextWithBg.Bg` primitive — never
`Hud.Bg`.

## RUNTIME GOTCHA: a `.str` with no header compiles to ZERO strings -> raw tokens

A localized string shown in game as its **raw reference token** (e.g. the kill feed printing
`ZM_AETHERIUM_KF_CRITICAL` instead of "Critical Kill") almost always means the `.str` file
**parsed to zero strings** — and the #1 cause is a **missing StringEd header**. A BO3/T7 `.str`
MUST begin with:

```
VERSION             "1"
CONFIG              "C:\projects\cod\t7\bin\StringEd.cfg"
FILENOTES           " "
```

then the `REFERENCE` / `LANG_ENGLISH` pairs, and end with `ENDMARKER`. Without `VERSION` first,
the compiler bails and produces **no** strings, so every `&"REF"` / `Engine.Localize("REF")`
falls through to the raw token. (The `CONFIG` path is metadata — it does NOT need to exist on
this machine.) This bit us 2026-07-04: `localizedstrings/zm_aetherium.str` had lost its top
header (the bottom `ENDMARKER` survived) when it was first split out of the Aetherium kit — keys,
`#precache`, the zone `localize,<name>` line, and the LUI `Engine.Localize(Engine.GetIString(x,
"CS_LOCALIZED_STRINGS"))` render were ALL correct; only the header was gone. The linker does NOT
loudly error on a headerless `.str` (no "bad string file" line), so the symptom only shows in game.
**When adding/editing a `.str`, copy an existing headered one and change only the entries.**

**`VERSION` must be the LITERAL first line — nothing above it, not even a `//` comment (regression 2026-07-04).**
The first header-restore fix put the `VERSION` block *below* a five-line `//` comment banner documenting the fix.
That re-broke it identically: the compiler still saw non-`VERSION` content first and parsed zero strings, so the
kill feed printed raw tokens again even though the header text was present. **StringEd `.str` files do NOT support
`//` comments anywhere** — keep the whole file to the pure `VERSION`/`CONFIG`/`FILENOTES` → `REFERENCE`/`LANG_ENGLISH`
→ `ENDMARKER` form. Put any explanatory note in the `FILENOTES` string value (a legal metadata field), never as a
comment line. Remember a `.str` edit only takes effect after a rebuild (linker recompiles it); the deployed+built
`.ff` is what the game reads, so re-sync + rebuild before re-testing.

**The T7 compiler AUTO-PREPENDS the `.str` filename to every `REFERENCE` — keep the keys BARE (regression 2026-07-05).**
The compiled string-table key is `<UPPERCASE_FILENAME>_<REFERENCE>`. For `zm_aetherium.str` the prefix is
`ZM_AETHERIUM_`, so a `REFERENCE KF_MELEE` line compiles to the in-game key `ZM_AETHERIUM_KF_MELEE`. **The GSC/LUI must
request that full prefixed name** (`&"ZM_AETHERIUM_KF_MELEE"`; see the `#precache( "string", … )` block in
`_zm_aetherium_hud.gsc`), but the `.str` `REFERENCE` line must stay **bare** (`KF_MELEE`). A well-meaning "rename the
keys to match the GSC" edit that put `ZM_AETHERIUM_KF_MELEE` in the `REFERENCE` line double-prefixed it to
`ZM_AETHERIUM_ZM_AETHERIUM_KF_MELEE`, so the lookup missed and the raw token showed — even though the strings *did*
compile. This was masked for a while by the missing-header bug above (zero strings compiled, so no key matched
regardless). **To verify which keys actually landed, decompress the built `en_<map>.ff`** — it is block-zlib (12
blocks, ~229 KB each; the zlib stream starts ~0x258 after the `TAff0000` header). A throwaway Node inflate-and-grep
confirmed `ZM_AETHERIUM_KF_MELEE → "Melee Kill"` with no double prefix. Also note: our `.str` uses **space** padding
(not tabs) between tag and value and still compiles fine here — tabs are the shipped convention but not required by
this (L3akMod) linker; the double-prefix, not the whitespace, was the bug.

## Architecture decision: standalone overlay + kit-proven stock-HUD override

Two ways to get custom LUI on screen:

- **(A) Override `t7hud_zm_custom.lua`** (the stock ZM HUD menu; engine loads it by
  the `LUI.createMenu.T7Hud_zm_factory` name). Lets you touch the real perk bar but
  you must re-`require`/re-instantiate **every** stock widget — drop one and you can
  break points/perks/ammo, or produce a **non-loadable `.ff`** (memory
  `lui-menu-can-break-map-load`). High risk by hand.
- **(B) Standalone always-on overlay** opened per-player with
  `player OpenLUIMenu("acc_hud")`. Purely **additive** — cannot break the stock HUD.
  (Recipe: MattFiler/zm_alien_isolation blackscreen/audiolog overlays.)

**We run BOTH, since 2026-07-03.** The Owen-C137 **Aetherium HUD kit** (docs/16) is a
complete, shipped implementation of the risky path (A): its `AetheriumHud.lua`
redefines `LUI.createMenu.T7Hud_zm_factory` AND re-requires/re-instantiates every
needed stock widget (`CoD.Zombie.CommonHudRequire` + CommonPre/PostLoadHud + the full
widget list) — exactly the "re-instantiate everything" burden that made a hand-rolled
override a non-loadable-`.ff` trap. So the architecture is:

- **Aetherium = the base HUD** (option A, kit-proven) — perk row, powerup row, party
  panel, ammo/loadout block, kill feed.
- **`acc_hud` = a slim additive overlay** (option B) for our uniques — perk/PaP info
  card, crosshair damage numbers, HOSTILES bar, and the gun-badge chip row.

Master flag **`level.acc_aetherium_hud`** (`_acc_lui.gsc::__init__`, hardcoded `true`)
flips the whole arrangement back to the pre-Aetherium stock-HUD-plus-overlay path.
Turning it off is a **3-step restore** (the `.csc` lives in the other VM and can't
read this bool): (1) this bool → `false` (re-arms the stock-HUD suppressors + the
`AccPerkBar`/`AccPowerupBar` mask feeds); (2) `_zm_aetherium_hud.csc` →
`#define ACC_AETHERIUM_HUD_ON 0` (stops the `LuiLoad` that replaces
`T7Hud_zm_factory`); (3) `acc_hud.lua createMenu` → re-add the retired widget
registrations (`AccPerkBar` / `AccPowerupBar` / `AccAmmoBlock` / `AccEquip`). The kit
also proves custom fonts: `ttf,fonts/*.ttf` zone lines + Lua `setTTF("fonts/x.ttf")`
(no `RegisterFont` needed) — the "biggest cheap tell" (generic BO3 UI font) is gone.

## The data bridge — `clientuimodel` clientfields (M1)

State-based server→client pipe (the pattern ColDog's Dead Shot perk-glow uses).
**Register in BOTH `.gsc` and `.csc`** (a `clientuimodel` field needs the CSC mirror
or the model never exists client-side — but **no callback handler** is needed; the
engine auto-pipes the value into the LUI model). Register via `REGISTER_SYSTEM` so
gsc/csc register in lockstep (a width/order mismatch corrupts the field and hangs
load).

```
GSC:  clientfield::register("clientuimodel","accField",VERSION_SHIP,bits,"int");
      self clientfield::set_player_uimodel("accField", value);
CSC:  clientfield::register("clientuimodel","accField",VERSION_SHIP,bits,"int",
          undefined, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT);   // no cb
Lua:  el:subscribeToModel(Engine.GetModel(Engine.GetModelForController(Instance),
          "accField"), function(m) local v = Engine.GetModelValue(m) ... end)
```

Other channels (available, less used):
- **M2 menu data** — `#precache("lui_menu_data", path)` + `SetControllerUIModelValue`
  + Lua `Engine.CreateModel`. For interactive `OpenMenu` menus — **and the house
  ZERO-clientfield HUD feed** (per-player, co-op replicated, spectate-pinned; every
  push must be a unique string — bump a seq/push_id — and feeders must re-push per
  life across the acc_hud reopen). Live users: `accLevel` (leveling chip),
  `accLbR1..10`/`accLbTot`/`accLbSrc`/`accLbLeaveHook` (leaderboard),
  **`accBoss1..5` (2026-07-24, boss health-bar rows — `_acc_boss_nameplate.gsc`
  `bb_*` → `CoD.AccBossBars` in acc_hud.lua; payload
  `"<NAME>|<pct 5%-steps>|<state 1/0/2>[|r<n>]"`, 4 Hz change-guarded, FIFO overflow
  queue, Paradise wipe = state 2, rows tinted per-boss via name-keyed
  `ACC_BB_BOSS_COLORS`)**. ⚠ CHANNEL-WIDE COST (2026-07-25 live-log find): every
  UNIQUE string pushed on this channel registers a client BGCACHE **configstring**
  (finite pool, exhaustion = the docs/22 #6 CTD class) — so QUANTIZE values and
  never stamp per-push uniquifiers except where an identical re-send must fire
  (menu-reopen repush windows). The same caution applies to accLevel/accLbR*.
- **M3 events** — `#precache("eventstring", NAME)` + `player LUINotifyEvent(&NAME,
  argc, ...)` + Lua `subscribeToGlobalModel(..., "scriptNotify", cb)` +
  `CoD.GetScriptNotifyData`. One-shot; the live path is documented-flaky.

## LUI engineering rules — the two scarce resources + the feasibility fence

The pipeline is capable but bounded by two hard engine limits (both empirically hit
on this map) plus a feasibility fence. **Read this before adding any HUD field or any
live-number readout.**

### Feasible vs blocked (proven in-repo)

**Feasible:** keyframe tweens (`beginAnimation`/`completeAnimation` → fade/slide/scale/
color-lerp), plain images (`setImage(RegisterImage(...))`), dynamic `UIText`, solid
rect shapes/frames/bars (the `CoD.TextWithBg.Bg` primitive), stock element effects
(`flicker`/`spinRandomly`/`playSound`), the GSC→clientfield→LUI bridge, suppressing
stock widgets via their uimodel, the standalone additive overlay
(`OpenLUIMenu('acc_hud')`, safe), and — kit-proven since 2026-07-03 — custom `ttf`
fonts and a full `T7Hud_zm_factory` override (via the Aetherium kit).

**Blocked / high-risk — do NOT plan around these:**
- **Real full-screen shaders** (blur, true scanline/CRT, chromatic aberration, bloom)
  — that's engine postfx/`.vision`, not LUI. Fake with offset/low-alpha layers only.
- **Custom materials (techset)** — headless shader-compile is blocked (docs/20 §14);
  use plain `image` assets. (This is why every acc widget draws
  `setImage(RegisterImage("i_acc_…"))`, never a custom material — see the perk/
  powerup/gun-badge rails below.)
- **Hand-rolling a stock-HUD-menu override** (`t7hud_zm_custom`, `RoundStatus.lua`,
  `Intermission_Main`) — can BUILD OK yet make a **non-loadable `.ff`**
  (`lui-menu-can-break-map-load`). Overlays are safe; a bare menu override is not.
  (The Aetherium kit is the one proven exception — it re-instantiates the entire
  stock widget list.)

### Scarce resource #1 — the clientuimodel bit pool is FULL

**Empirically confirmed 2026-06-28 / recounted, still true:** the `clientuimodel`
scope holds **66 bits across 8 fields** (`_acc_lui.gsc::__init__`):

| field | bits | drives |
|---|---|---|
| `accOcTier` | 4 | held-gun Overclock tier (0..10) — OC report card + gun-badge chip |
| `accPerkCard` | 7 | perk/PaP info-card selector |
| `accPapTier` | 3 | held-gun PaP tier (0..3) — PaP report card + gun-badge chip |
| `accMegaMask` | 10 | Mega-perk bitmask (10 perks; PhD bit 8, Electric Cherry bit 9) |
| `accDmgNum` | 18 | crosshair damage number `min(dmg,65535)*4 + headshot + parity` |
| `accOwnedMask` | 10 | owned-perk bitmask |
| `accPowerupMask` | 7 | timed/instant power-up bitmask |
| `accRoundRing` | 7 | round-progress percent 0..100 (drives the HOSTILES bar) |

Adding a **wider** field overflows the shared zombies pool and breaks a STOCK field
(`zmhud.swordEnergy`) → `Com_ERROR` at load. **Proven by a throwaway probe:** a
registered-but-unused **24-bit** `accProbe24` clientuimodel field **failed to load
(Com_ERROR)** → **headroom is < 24 bits.** Only ~4 bits are cheaply reclaimable
(narrow `accDmgNum` by capping the displayed number). So:

- **Prefer client-side state over a new field.** Round number is engine state
  (`level.round_number`, read client-side already) — never spend a field on it.
  Power-up countdowns can tween locally from known stock durations off the mask bit
  flipping 0→1. **Bit-pack** low-range counts.
- **Reuse retired slots** — `accOcTier` repurposed the dead `accLuiTest` slot
  in-place (same width, same registration order → bit layout unchanged, no overflow).
- **When a private per-player field is genuinely needed, use a DIFFERENT scope** — but
  know that **the `toplayer` pool is now FULL too** (2026-07-15 incident: growing it +17
  bits made the STOCK `visionset_lerp` registration fail with `Com_ERROR ... toplayer is
  out of space` and the **map stopped loading** — the overflow always blames the innocent
  LAST registrant, memory `actor-clientfield-bit-budget`). **Never add/widen a toplayer
  field without shaving an equal number of bits from our existing ones** (precedent: the
  4-bit `acc_objective` widen was paid for by `acc_box_gun` 6→5); for
  new payloads prefer a zero-bit transport (a dvar read from LUI, client-side derivation
  from already-shipped models, or the phase index itself). **SHAVE ONLY WHAT IS ACTUALLY
  SPARE** — the same incident's hot-fix also shaved `acc_badges` 6→4 on a wrong audit
  ("only 3 badge bits are live"; six were), which silently orphaned the HICAL + WARHD chips
  at bits 4/5 until it was restored to 6 later that day. **Before shaving a mask field,
  check the highest bit its owning module actually registers.** The current acc_* toplayer
  total is **59 bits** (= the last known-loading build's total, same 8 fields). The toplayer
  scope is bridged
  to a same-named UI model by `_zm_aetherium_hud.csc::set_ui_model_value` (registered
  `&set_ui_model_value` on every toplayer field) and carries `acc_shards` (10) / `acc_mb`
  (5) / `acc_exo` (4) / `acc_maxhp` (9) / **`acc_badges`** (6-bit gun-badge mask, bits 0..5
  all live) /
  **`acc_implants`** (16-bit pause implant nibbles) / **`acc_objective`** (4-bit pause
  "what next" run-phase, 0..12 milestone ladder incl. per-trench-gate descent states;
  pushed by `_acc_lui::objective_watch`) / **`acc_box_gun`** (5-bit mystery-box
  weapon-usage id 0..31, pushed by `_zm_aw_mysterybox::acc_set_box_gun` on box reveal;
  `PromptMysteryBox.lua` maps id→codename→card — see the triggerstring note below).
  The objective's soft progress numbers ride the **`acc_obj_detail` dvar** (host-only by
  nature — remote co-op clients render nothing) and its boss warning + perk count are
  fully client-side — see docs/11.
  **TOPLAYER = THE POV ENTITY'S PLAYERSTATE, AND SPECTATE MOVES IT (2026-07-16).** While a
  dead player spectates a teammate, every toplayer field delivers the SPECTATED player's
  values (their badges/currency on the spectator's HUD — inherent engine behavior, fine).
  The trap is the way back: per the stock `clientfield::register` doc, the engine only
  "generates callbacks for a value of 0, when the entity is new" if the field registered
  with **`CF_CALLBACK_ZERO_ON_NEW_ENT`**. Our fields originally registered with
  `!CF_CALLBACK_ZERO_ON_NEW_ENT`, so on respawn (POV back to self = a NEW ent) a true value
  of 0 never fired a callback and the UI model kept the spectated player's value forever —
  the "spectator keeps the other guy's badges after respawn" + "gun randomly has all the
  badges" bug pair. **Every acc_* toplayer field must register WITH
  `CF_CALLBACK_ZERO_ON_NEW_ENT`** (client-only arg — not part of the bit layout, gsc/csc
  lockstep unaffected). The
  **`world`** scope (broadcast to all clients) carries the co-op party fields
  (`player_health_N` / `player_states_packed` / `player_shards_N` / `player_mb_N` /
  `player_exo_N`). Both scopes still register gsc↔csc in lockstep. See docs/11 for
  the pool audit; memory `aetherium-hud-adoption`.
- **The full-LUI co-op roster migration stays budget-blocked** — even a 24-bit packed
  roster field does not fit the clientuimodel pool; the roster stays a GSC server
  hudelem (`_acc_health_bars.gsc`), trimmed/change-guarded there.

### Scarce resource #2 — the `string` BG-cache (2048 cap) → SetValue, not SetText

**NEVER `SetText` a live/unbounded number on a server hudelem — use `SetValue`.** The
engine keeps a **`string` BG-cache, cap 2048 per match**, fed by every DISTINCT string
passed to a hudelem `SetText`; each one **permanently burns a slot** (never freed) →
`BG_Cache_GetIndexInternal - Exceeded '2048' items for type 'string'` CTD. A number via
**`SetValue` costs ZERO slots** (stock `_zm.gsc countdown_hud SetValue`). Rules,
verified live and applied across `_acc_health_bars.gsc` / `_acc_data_shards.gsc`:

- Numbers that vary widely over a match (**score/points**, accumulating counters) **must**
  be `SetValue`. `SetText` is only for **constant** or **small bounded** strings —
  change-guard those too.
- The merged "label + N numbers" `SetText` line is a trap: its distinct-string count is
  the **product** of the numbers' ranges (`501 shards × 11 exo × 26 mb ≫ 2048`). Split
  the runaway field out.
- `alpha = 0` (hidden) does **NOT** prevent registration — it happens on the `SetText`
  *call*.
- **To keep a text PREFIX on a crash-safe number and render flush, use two elements:** a
  right-aligned `SetText` element holding the bounded prefix (e.g. `"… $"`) with a fixed
  right edge, and a left-aligned `SetValue` number 2px after it → `$12500` renders flush
  every frame and the unbounded number stays out of the cache. **Do NOT use the hudelem
  `.label` field** — verified in-game 2026-06-26 it does **not draw** on
  `hud::createFontString` server hudelems (only the bare `SetValue` number rendered).
- Bounded numbers are fine in the `SetText` half: **round number** (≤~255 distinct →
  `"Round " + N`, change-guarded), tier 0-10, shards alone (~501 distinct, safe by
  itself). This is the SERVER-side twin of the `triggerstring` 250-cap `SetHintString`
  rule (memories `string-cache-setvalue-not-settext` + `triggerstring-cap-hint-strings`).
- **Mystery-box weapon card = the `triggerstring`-safe pattern in action (2026-07-13).**
  The box take-hint MUST stay a CONSTANT string (`"Hold [+activate] for Printed Weapon"`) —
  appending the gun's display name per roll burned one permanent `triggerstring` slot per
  distinct gun (~50/session, tipped the 250 cap). But the LUI cursor-hint router
  (`ZMCursorHintNew.lua`) normally derives the box card's weapon by *parsing the name out of
  that hint*, so a constant hint left it on the "Unknown weapon" blank card. FIX: drive the
  card off the **`acc_box_gun` clientfield integer** instead of any string. `PromptMysteryBox.lua`
  subscribes to the model (`self:subscribeToModel(Engine.CreateModel(...,"acc_box_gun"))`),
  maps the id → weapon codename (a table mirroring `tools/gun_ids.json`) →
  `CoD.GetWeaponDataByName` for the name/desc/icon, and shows a clean generic card at id 0.
  The card desc also carries **boss-item eligibility tags** (`AetheriumWeapons.lua` header comment):
  `[ENERGY]` → Plasma Generator / `[EXPLOSIVE]` → Warhead Bomber, `[MELEE]` → Berzerker (Leviathan Axe / Action Figure /
  Ballistic Knife stab), `[TURBO]` → Turbocharger (Havoc) — one per weapon-gated implant (docs/09). **General rule: any
  per-gun/per-entity card text belongs on a clientfield int, never a per-value `SetHintString`.**
  Memory `box-gun-card-via-clientfield-not-hint`.

## The 4-file contract (one menu)

For menu name `acc_hud` (all five strings must match exactly):
1. **Lua** `ui/uieditor/menus/hud/acc_hud.lua` — `function LUI.createMenu.acc_hud(Instance)`.
2. **Zone** `rawfile,ui/uieditor/menus/hud/acc_hud.lua` (+ `image,<name>` per custom image; stock `ui_add`/`uie_flipbook` need no line).
3. **CSC** entry `main()`: `LuiLoad("ui.uieditor.menus.hud.acc_hud");` (dot path).
4. **GSC**: `#precache("lui_menu","acc_hud");` + per-player `m = player OpenLUIMenu("acc_hud");`.

Plus the clientfield register (gsc+csc) for each field the widgets read.
A `.lua` is a **rawfile** (copied verbatim, parsed at runtime) — a Lua **syntax**
error shows at load, NOT at link, so the linker passing ≠ the Lua being correct.

## Perk bar — the two-mask bridge (LIVE) + `CoD.AccPerkBar` (restore path)

A perk bar whose **icon colour encodes Mega state** — **RED = base, TEAL = Mega'd**,
hidden when not owned. The **data bridge is LIVE and feeds the Aetherium perk row**;
the standalone `CoD.AccPerkBar` widget is the pre-Aetherium restore path.

- **Two-mask data bridge (always on).** `accOwnedMask` (bit i = owns perk i+1) +
  `accMegaMask` (bit i = Mega'd), perk_card_index order. `_acc_lui.gsc::perk_state_watch()`
  (per-player 0.25s poll, threaded unconditionally) computes the owned bit from
  `acc_mega_bottles::owns_paused_or_hacked` (NOT `owns_or_paused` — a hacked perk must keep
  its row slot; `owns_or_paused` reads a hacked perk as not-owned) and the mega bit from
  `has_mega_perk`, and pushes them, so the bar tracks buys / downs /
  EMP-pause / re-buys with **no manual event tracking**. Under Aetherium these two
  masks drive the **rewired `AetheriumPerksContainer`** (Mappings/AetheriumPerks.lua
  carries the bit→icon table); pre-Aetherium they drive `CoD.AccPerkBar`.
- **Image, not material.** Icons are 2D UI `image` assets drawn via
  `setImage(RegisterImage("i_acc_perk_<perk>_base"|"_mega"))` (countryside `PerkImage`
  idiom) — no custom material/techset, so it sidesteps the shader-compile blocker
  (docs/20 §14). 20 images (10 perks × base/mega) in `source_data/acc_perk_shaders.gdt`
  (deploy via `tools/deploy_perk_shaders.ps1`); one `image,<name>` zone line each
  (`i_acc_perk_{jugg,revive,speed,doubletap,staminup,mule,deadshot,widows,phd,cherry}_{base,mega}`,
  `ACC_PERK_COUNT = 10` in acc_hud.lua; PhD bit 8 + Electric Cherry bit 9 each ship base+mega).
- **No bitwise ops in Lua 5.1/HavokScript** — the widget tests bit i arithmetically
  (`math.floor(mask / 2^i) % 2`).

### Restore path — hiding the stock perk bar via clientfield suppression (Aetherium OFF)

When `level.acc_aetherium_hud` is **off** (Aetherium replaces the whole stock HUD when
on, so no suppression is needed), `_acc_lui.gsc` hides the stock perk bar so `AccPerkBar`
doesn't duplicate it. Hard-won mechanism:

- **A usermap can NEVER shadow a base-game asset by name.** Zones load `zm_patch →
  zm_common → zm_levelcommon → <usermap>` (usermap **last**), and the "Redundant asset"
  rule keeps the **first-loaded** copy and discards the later (usermap) one. So overriding
  a stock image/material name with a transparent usermap asset does **nothing** (both
  `specialty_*_zombies` and `i_t7_specialty_*` override attempts failed for this reason).
- **The stock perk bar is a LUI widget** (`CoD.ZMPerksContainerFactory` → `LUI.UIList`
  "PerkList" → `CoD.PerkListItemFactory`) that shows a perk icon only while the per-player
  model `hudItems.perks.<key>` is `> 0`.
- **Hide it from GSC by zeroing those models.** `_acc_lui::clear_stock_perk_hud()` writes
  all 9 `hudItems.perks.<key>` fields to 0. **Cosmetic only** — perk effects come from
  engine `SetPerk`, untouched. Field names verified vs `_zm_perks.gsh PERK_CLIENTFIELD_*`
  (aliases: staminup→`marathon`, fastreload→`sleight_of_hand`, deadshot→`dead_shot`,
  additionalprimaryweapon→`additional_primary_weapon`).
- **Zero flash:** `stock_perk_hud_suppressor()` clears on the stock `perk_acquired`
  notify, which fires the **same server frame** as the stock OWNED set with no wait between
  (`_zm_perks.gsc:756→780`) — so the client's end-of-frame snapshot never carries OWNED and
  the icon never appears on buy. `perk_state_watch`'s 0.25s clear re-asserts for the rarer
  unpause path.

## Power-up bar — `CoD.AccPowerupBar` (restore path under Aetherium)

A centered row of Ronan power-up icons on the same `setImage(RegisterImage(...))` image
rail as the perk bar. Driven by the 7-bit `accPowerupMask`. **Under Aetherium this is a
restore-path widget** — Aetherium's own PowerupsContainer reads the stock powerup
clientfields, so `powerup_state_watch()` + `suppress_stock_powerup_hud` only run when
`level.acc_aetherium_hud` is off (else suppressing the stock icons would blank Aetherium's
row). The mechanism, kept for the restore path:

- **Timed power-ups** (bit 0 Insta-Kill / 1 Double Points / 2 Fire Sale) show **while
  active**. `powerup_state_watch()` (0.25s poll) reads the stock `level.zombie_vars` active
  flags and pushes the mask on change; the stock icons for these 3 are suppressed.
- **Instant power-ups** (bit 3 Nuke / 4 Max Ammo / 5 Carpenter / 6 Random Perk) have no
  active window, so they **flash ~3s on pickup** via a `self.acc_flash_<name>_until` stamp
  ORed into the mask while live. Two signal paths: **dedicated** (Nuke `nuke_triggered` /
  Max Ammo `zmb_max_ammo_level`) and **generic** (`powerup_dropped`→`powerup_grabbed` by
  `powerup.powerup_name`, works for ANY powerup by name).
- **Images:** `i_acc_powerup_{instakill,double,sale,nuke,maxammo,carpenter,randomperk}`.

## PaP tier icon — roman-numeral cyber shield (`CoD.AccPapTierIcon`)

**RETIRED 2026-07-08 — the PaP shield is now a chip in the unified gun-badge row (next
section); the class is kept in acc_hud.lua as the restore path.** It replaced the old
bottom-right `"PaP TIER x/3"` font string with a small teal hex roman-numeral shield
(I/II/III) driven by the existing `accPapTier` clientuimodel (0..3, 0 = hidden).

## Gun badge row — unified held-weapon enhancement chips (`CoD.AccGunBadgeRow`, 2026-07-08)

User: "unify the gun badges — a row under the gun's ammo; start from the right and add to the
left." ONE right-anchored row of uniform chips under the Aetherium ammo readout showing every
enhancement of the HELD weapon. Replaces the three scattered one-offs, each of which had its own
widget, plumbing and hand-tuned position (`AccPapTierIcon` / `AccOcTierText` / `AccMuleTag` — all
retired in place as the restore path).

- **Row model:** the registry `ACC_GUN_BADGES` in acc_hud.lua, in PRIORITY order — entry `[1]`
  renders rightmost, later entries pack LEFT. Chips are fixed-width, uniform height 47. `Layout()`
  re-packs on every model change, so the row is always gap-free.
- **Pennant art (user PNGs, 2026-07-08; latest = `cyber_city_final (1).zip` FINAL v6, 2026-07-15):**
  every live badge is a 5:7 pennant card with its own
  baked background — PaP I/II/III (replaced the Ronan hex shields **in place**, same
  `i_acc_pap_tier{1,2,3}` asset names; old PNGs kept as `*.acc-hexshield-orig`), `i_acc_oc_tier1..10`
  (Lv1–Lv10), `i_acc_badge_mule`, `i_acc_badge_turbo`, `i_acc_badge_plasma`, `i_acc_badge_berzerker`, `i_acc_badge_high_caliber`, `i_acc_badge_warhead`.
  The FINAL v6 pack regenerated all 19 badges (chevron crest removed, icons auto-fit to the pennant at
  max size) and replaced the last 3 placeholders (plasma / warhead / high-caliber) with real art;
  `i_acc_badge_nuclear` is dead art since the 07-14 Nuclear→Plasma+Warhead item split (GDT block kept,
  no zone line, no Lua reference).
  Icon chips draw the art **full-bleed with NO plate** (a rectangle would show at the pennant notch);
  text-chip defs (future badges without art yet) still get the navy plate. Since the "enhanced" packs
  (badges_16/17_enhanced, 2026-07-10/11) the 400×560 masters ship **AS-IS** — the old pre-resize to
  128×128 (HQ bicubic, System.Drawing, TileFlipXY) is RETIRED; the linker converts the PNG itself
  (`noMipMaps` like every HUD icon) and the 34×47 quad (~5:7) draws it at the true source aspect. New
  badge art: drop the 400×560 (or any 5:7) RGBA PNG in `source_data/acc_perk_shaders/_images/` as
  `i_acc_badge_<x>.png`, clone an `image.gdf` GDT block + zone `image,` line, run
  `tools/deploy_perk_shaders.ps1` (copies to install + `gdtdb /update`) before linking.
  **`noMipMaps 1` is LOAD-BEARING for HUD images, not just a crispness choice (2026-07-12):**
  flipping it to 0 moves the image to the STREAMED pool — its assetinfo payload collapses to a
  ~276-byte header and the HUD draws the black/default image. For sharper art use
  `compressionMethod uncompressed` (kills the DXT mush on thin lines/text; proven combo =
  `i_acc_data_shard` and the 19 implant images) and keep `noMipMaps 1`.
- **Data (two lanes, one row):**
  - *Tier badges* (int value): ride the **existing** clientuimodels `accPapTier` (0..3) and
    `accOcTier` (0..10) — those keep flowing anyway (the PaP/OC report cards read the same models), so
    the row re-consumes them with **zero clientuimodel pool growth** (pool is FULL, docs/11).
  - *Flag badges* (on/off): share ONE 6-bit `acc_badges` **toplayer** clientfield bridged to a
    same-named UI model (`&set_ui_model_value`, the acc_shards escape hatch above). **bit 0 = MULE**
    (held gun is the one Mule Kick removes on a down — absorbed the former 1-bit `acc_mule` field,
    replaced in-place in gsc+csc lockstep), **bit 1 = TURBO** (Turbocharger implanted and the held gun
    is a Havoc), **bit 2 = PLASMA** (Plasma Generator implanted and holding an energy weapon), **bit 3 =
    BRZ** (Berzerker implanted and holding a melee weapon it speeds up — Leviathan Axe / Action
    Figure; the knife-bash surface is deliberately not a trigger or the badge would pin on
    permanently), 2 spare bits.
- **Server engine = `_acc_gun_badges.gsc`** (dedicated module, 2026-07-08). A **predicate registry**:
  `init()` calls `register_badge(bit, &pred_fn)` once per flag badge; the per-player `badge_watch`
  (0.25s change-guarded poll, threaded from `_acc_main::on_player_connect`) recomputes the whole mask
  each tick by calling every predicate on the held weapon and pushing `acc_badges` on change. Each
  predicate (`pred_mule` / `pred_turbo` / `pred_nuclear` / `pred_berzerker`) is `self=player, cur=held weapon → bool`,
  self-contained and independently correct, so one badge can never break another and any order of
  operations converges within a tick. The `acc_badges` clientfield is *registered* in
  `_zm_aetherium_hud.gsc/.csc` (toplayer bit-layout lockstep); the module only reads/writes it.
- **Robustness notes baked into the predicates:**
  - *Mule*: resolves every primary to its `true_base` before the `is_weapon_included/upgraded` filter
    AND for the held-gun match — so an active perk/PaP twin can't drop the count below 3 and blink the
    badge off, and holding a twin of the 3rd gun still lights it. Naturally hides while downed (held =
    laststand pistol) and when Mule is lost/`_retain_perks`.
  - *Plasma*: reuses `acc_damage::is_energy_weapon` (single source of truth for the buff list) + the
    two explosive primaries (Mahem launcher `s1_mahem` and War Machine drum GL `t6_war_machine`), so
    the badge and the damage buff can never disagree.
- **Adding a badge:** (1) write a `pred_x(cur)` in `_acc_gun_badges.gsc`, (2) `register_badge(bit,
  &pred_x)` in its `init()`, (3) one entry in `ACC_GUN_BADGES` (acc_hud.lua) with `bit = <bit>`. No new
  widget, no new clientfield, no per-badge positioning. (Widen the 6-bit `acc_badges` in BOTH
  `_zm_aetherium_hud.gsc`+`.csc` in lockstep only if a 7th flag badge is needed.)
- **Position:** right edge x 1061, y 644..691 (virtual) — flush under the Aetherium reserve-ammo line
  (AetheriumLoadout.lua: reserve x 968..1057 / y 629..638). CAVEAT: the AAT ammo-mod icon occupies
  x 1037..1061 / y 641..665 when an AAT is rolled — if they collide in-game, raise `ACC_GUN_BADGE_BOTTOM`
  or grow `ACC_GUN_BADGE_RIGHT`. Tune in-game.

## Implant slot cards — `CoD.AccImplantRow` (+ the pause-menu panel twin)

Left-HUD implant display, full PNG since 2026-07-12 (user pack `cyber_city_implant_hud`, v3 holo
set; replaced the GSC `IMPLANT N`/`CARRYING` hudelem text lines — up to 4 per-client hudelems
freed, `_acc_boss_items::sync_items_hud` is now just the clientfield push).

- **Art (21 images, the badge recipe above verbatim; v4 "compact" pack 2026-07-12 late; emblems
  refreshed by `cyber_city_final (1).zip` FINAL 2026-07-15 — 13 real emblems, the high-caliber +
  warhead placeholders replaced; zip slot bars were byte-identical, unchanged):**
  `i_acc_implant_slot1..3` (+`_dim` twins) = **962×176** bars (5.47:1) with a big readable
  `IMPLANT N` title ONLY — the tiny sub-line was dropped (minified below readability); `i_acc_implant_holding[_dim]`
  = the 4th "carrying" bar; `i_acc_emblem_<item>` ×13 = **glyph-only** 256×256 chips (no hex frame).
  NAME-MAP TRAP: the zip numbers warhead=12 / high-caliber=13, our tables number high-caliber=12 /
  warhead=13 — always map zip files by ITEM NAME, never by index. `i_acc_emblem_nuclear_energy` is
  dead art (item removed 07-14).
  **State = PURE IMAGE SWAP**: lit bar when occupied, `_dim` when not — the dim art bakes in 35%
  desat / 60% bright / **50% alpha**, so never layer a code `setAlpha` on top (compounds to 25%).
  Overlay geometry from the v4 README: glyph = **92% of bar height**, x-center at **90.1% of bar
  width** (shared named constants across both files) — same window on the holding bar.
- **Widget:** 4 bar `UIImage`s (3 slots + HOLDING, always visible) + one emblem overlay each.
  All 13 emblem materials are `RegisterImage`d ONCE into a num-keyed handle table; refresh just
  `setImage`s pre-registered handles (the countryside PerkImage idiom). Bars draw **230×42** at
  x 32 from y 220, stride 48. Tune in-game.
- **Data:** the EXISTING 16-bit `acc_implants` toplayer→uimodel nibble pack (bits 0-3/4-7/8-11 =
  Slot 1/2/3, 12-15 = carried; `push_implants_clientfield`) — **zero new pool cost of any kind**.
  Subscribed via `Engine.CreateModel` (the toplayer no-node-until-first-write trap, see the badge
  row's ACCESSOR CHOICE note) + an explicit initial `Refresh` for mid-run HUD rebuilds. Nibble
  decode is floor-division (no bit ops in HKS Lua 5.1).
- **Pause-menu twin** (`AetheriumStartMenu.lua`): the same 4 bars + overlays at the **EXACT same
  coords as the in-game bars** (x32 / y220 / 230×42 / stride 48) so pausing OVERLAPS and covers the
  in-game duplicates (user 2026-07-12: "the menu needs to overlap the in game HUD"). The pause
  menu's full-screen DarkOverlay dims the in-game HUD; the opaque bars cover the copies; the
  name/desc text sits to the right (x274→790, clearing the x868 button column) — `ACC_IMPLANT_INFO`
  carries each item's name/desc/`emblem`. New elements are wired into the menu's teardown `:close()`
  block — mandatory (LUI leak class).
- **Adding/renumbering an item:** update `build_item_pool()` (GSC) + `ACC_IMPLANT_INFO`
  (AetheriumStartMenu.lua) + `ACC_IMPLANT_EMBLEMS` (acc_hud.lua) + drop the new
  `i_acc_emblem_<item>.png` through the badge asset recipe. `item.num` must stay ≤ 15.

## HOSTILES threat bar — `CoD.AccRoundRing` (legacy name, renders a BAR)

The upper-right threat indicator. **The clientfield and widget keep the legacy
`accRoundRing` / `CoD.AccRoundRing` name, but it renders a smooth horizontal BAR — the
radial-ring approach (docs/11) was abandoned.** `round_ring_watch()` (per-player 0.25s
poll) pushes `accRoundRing` = PERCENT remaining (`remaining/total*100`, where `remaining`
= alive on field + still-to-spawn and `total` = the round's peak count). The raw counts
would need wider clientfields than the (full) clientuimodel pool allows, so we push the
percent (7 bits). The bar is always visible.

## Files

- `ui/uieditor/menus/hud/acc_hud.lua` — the additive overlay: `CoD.AccPerkCard`,
  `CoD.AccDmgNum`, `CoD.AccGunBadgeRow`, `CoD.AccRoundRing` (HOSTILES bar),
  `CoD.AccShardIcon`, plus the restore-path widgets (`CoD.AccPerkBar`,
  `CoD.AccPowerupBar`, `CoD.AccPapTierIcon`, `CoD.AccOcTierText`, `CoD.AccMuleTag`,
  `CoD.AccAmmoBlock`, `CoD.AccEquip`).
- `ui/uieditor/menus/hud/AetheriumHud.lua` — the base HUD (kit `T7Hud_zm_factory`
  override + rewired perk/party containers).
- `scripts/zm/zm_abandoned_cyber_city/_acc_lui.gsc` / `.csc` — server register + open +
  set / client mirror register; `perk_state_watch()` drives the owned/mega masks,
  `round_ring_watch()` the HOSTILES bar.
- `scripts/zm/_zm_aetherium_hud.gsc` / `.csc` — the kit's server/client half: the
  `world` + `toplayer` clientfield registrations (party fields, `acc_shards`/`acc_mb`/
  `acc_exo`/`acc_maxhp`/`acc_badges`), the `set_ui_model_value` toplayer→uimodel bridge,
  and the kill-feed `#precache("string", …)` block.
- `scripts/zm/zm_abandoned_cyber_city/_acc_gun_badges.gsc` — the gun-badge predicate
  registry that computes + pushes `acc_badges`.
- `scripts/zm/zm_abandoned_cyber_city.csc` — `LuiLoad` in `main()`.
- `zone_source/zm_abandoned_cyber_city.zone` — scriptparsetree + `rawfile` (the `.lua`) +
  `image,` lines for the custom icons.
- `source_data/acc_perk_shaders.gdt` — custom perk/powerup/badge `image` assets (Ronan's
  Cyberpunk Shaders + the user pennant PNGs). Source PNGs under
  `source_data/acc_perk_shaders/_images/`.
- `tools/deploy_perk_shaders.ps1` — deploy the GDT + images to the Mod Tools
  `source_data/` + `gdtdb /update` (the GDT lives outside the usermap sync).

## Source maps (cloned in tmp/, mined into docs/16)

- **MattFiler/zm_alien_isolation** — minimal standalone overlay (our overlay template).
- **Owen-C137/Aetherium-Hud** — the shipped `T7Hud_zm_factory` override kit (our base HUD).
- **ohm-nabar/zm_building** — `t7hud_zm_custom.lua` override + clientuimodel widget; the
  on-disk `zmammo_*_abbey.lua` bindings our restore-path ammo block copies from.
- **ColDog5044/zm_countryside** — real perk-bar glow widgets (`hb21perklistitemfactory.lua`).
- **kelson8/bo3-Zombies-Test-Map** — GSC↔LUI menu round-trip (interactive-menu blueprint).
