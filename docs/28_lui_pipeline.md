# 28 — LUI (Lua) client pipeline

The premium client-side UI layer: custom LUI HUD widgets driven by GSC. This is
the substrate for the perk-icon glow, premium purchase cards, the Cyberware tree
menu, live counters, and the boss bar. Server-HUD cards (`_acc_ui.gsc`,
docs/27) remain the all-GSC fallback; LUI is the ceiling.

Status: **foundation built, gated on L3akMod (see below).** The foundation is a
standalone always-on overlay (`acc_hud`) + a `clientuimodel` test banner. Once it
loads in-game, real widgets replace the banner.

## HARD REQUIREMENT — L3akMod (build) + `-unsafe-lua` (runtime)

The public BO3 mod tools linker **cannot compile a `rawfile,*.lua` source file** —
it errors `ERROR: Lua not supported`. Custom LUI needs **L3akMod** (DTZxPorter):

1. **Build time:** overwrite `<bo3_root>\bin\libtiff64r.dll` with the L3akMod
   **v1.0.4** build (https://dtzxporter.com/tools/l3akmod). Prereqs: VS2013 **and**
   VS2015 x64 runtimes (both verified present on this box, 2026-06-13). The
   original DLL is backed up at `bin\libtiff64r.dll.acc-orig-backup`
   (sha256 `9813F88B…589B63D9`, 441856 bytes) — restore it to uninstall.
   - Alternative: pre-compiled `*.luac` can be linked without L3akMod, but
     producing T7/HavokScript-compatible bytecode itself needs L3akMod's compiler,
     so the DLL swap is the practical path.
   - **CREDIT (required by L3akMod's license):** the **D3V Team** must be credited
     for L3akMod use — add them to the map's in-game/Workshop credits.
   - Installed + verified live 2026-06-13 (linker prints
     `[L3akMod (D3V)] (v1.0.4) ... loaded successfully!`; build exit 0, the
     `Lua not supported` error gone).
2. **Runtime: NO launch flag needed on Steam BO3** (verified live 2026-06-13). Our
   menu executed in-game and a Lua bug in it threw **UI Error 43408** - which proves
   the custom Lua RAN (it was not sandbox-blocked). The community **`-unsafe-lua`**
   arg is a **BOIII-client** flag, not a Steam BO3 one: on Steam it logs
   `Unknown command "-unsafe-lua"` and does nothing. It is intentionally NOT passed
   by the launchers. (So the old "players need -unsafe-lua" ship-blocker is moot for
   Steam - the compiled LUI is baked into the `.ff`.)

## RUNTIME GOTCHA: `Hud.Bg` -> UI Error 43408

`CoD.Menu.NewForUIEditor()` does **not** expose a `.Bg` member. `Hud.Bg:setAlpha(..)`
indexes nil and throws **UI Error 43408** at runtime (it compiles fine - rawfile Lua
errors only surface at load, never at link). The commented-out `audiolog.lua` used
`Hud.Bg`; the only shipped-ACTIVE standalone overlay (`blackscreen.lua`) never does.
**Lesson: only copy from shipped-ACTIVE files, not commented-out ones**, and treat
the linker passing as proof of *syntax* only, never of runtime API validity. The
runtime oracle for LUI errors is the on-screen `UI Error <code>` box (the code is
generic "a Lua error occurred in the UI"; the traceback is not in console_mp.log).

## Architecture decision: standalone overlay, NOT a stock-HUD override

Two ways to get custom LUI on screen:

- **(A) Override `t7hud_zm_custom.lua`** (the stock ZM HUD menu; engine loads it by
  the `LUI.createMenu.T7Hud_zm_factory` name). Lets you touch the real perk bar but
  you must re-`require`/re-instantiate **every** stock widget — drop one and you can
  break points/perks/ammo. High risk; needs the stock HUD source we don't have.
  (Recipe: ohm-nabar/zm_building.)
- **(B) Standalone always-on overlay** opened per-player with
  `player OpenLUIMenu("acc_hud")`. Purely **additive** — cannot break the stock HUD.
  The "perk icon glow" is an additive glow sprite drawn **over** the stock perk
  bar's position. **This is what we use.** (Recipe: MattFiler/zm_alien_isolation
  blackscreen/audiolog overlays.)

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

Other channels (not used by the foundation, but available):
- **M2 menu data** — `#precache("lui_menu_data", path)` + `SetControllerUIModelValue`
  + Lua `Engine.CreateModel`. For interactive `OpenMenu` menus (Cyberware tree).
- **M3 events** — `#precache("eventstring", NAME)` + `player LUINotifyEvent(&NAME,
  argc, ...)` + Lua `subscribeToGlobalModel(..., "scriptNotify", cb)` +
  `CoD.GetScriptNotifyData`. One-shot; the live path is documented-flaky.

## The 4-file contract (one menu)

For menu name `acc_hud` (all five strings must match exactly):
1. **Lua** `ui/uieditor/menus/hud/acc_hud.lua` — `function LUI.createMenu.acc_hud(Instance)`.
2. **Zone** `rawfile,ui/uieditor/menus/hud/acc_hud.lua` (+ `image,<name>` per custom image; stock `ui_add`/`uie_flipbook` need no line).
3. **CSC** entry `main()`: `LuiLoad("ui.uieditor.menus.hud.acc_hud");` (dot path).
4. **GSC**: `#precache("lui_menu","acc_hud");` + per-player `m = player OpenLUIMenu("acc_hud");`.

Plus the clientfield register (gsc+csc) for each field the widgets read.
A `.lua` is a **rawfile** (copied verbatim, parsed at runtime) — a Lua **syntax**
error shows at load, NOT at link, so the linker passing ≠ the Lua being correct.

## Cyberpunk perk bar — replaces the stock perk bar (IMPLEMENTED + in-game verified, 2026-06-14)

Our own perk bar (Ronan's Cyberpunk Shaders) whose **icon colour encodes Mega state** —
**RED = base, TEAL = Mega'd**, hidden when not owned — with the **stock perk bar hidden**
so there's no duplication. All 8 live perks. `CoD.AccPerkBar` in `acc_hud.lua`.

- **Image, not material.** Icons are 2D UI `image` assets drawn via
  `setImage(RegisterImage("i_acc_perk_<perk>_base"|"_mega"))` (countryside `PerkImage`
  idiom). A plain `image` needs **no custom material/techset**, so it sidesteps the
  geometry-material shader-compile blocker (docs/29 §14). 16 images (8 perks ×
  base/mega) in `source_data/acc_perk_shaders.gdt` (deploy via
  `tools/deploy_perk_shaders.ps1`); one `image,<name>` zone line each.
- **Two-mask data bridge.** `accOwnedMask` (bit i = owns perk i+1) + `accMegaMask` (bit
  i = Mega'd), perk_card_index order. `_acc_lui.gsc perk_state_watch()` (per-player 0.25s
  poll) computes both from `owns_or_paused`/`has_mega_perk` and pushes them, so the bar
  tracks buys / downs / EMP-pause / re-buys with **no manual event tracking**. **Lua
  5.1/HavokScript has no bitwise ops** — the widget tests bit i arithmetically
  (`math.floor(mask / 2^i) % 2`). `CoD.AccPerkBar` packs owned perks left-to-right.

### Hiding the stock perk bar — clientfield suppression, NOT asset override (hard-won)

- **A usermap can NEVER shadow a base-game asset by name.** Zones load `zm_patch →
  zm_common → zm_levelcommon → <usermap>` (usermap **last**), and the "Redundant `<type>`
  asset 'X' found in zone 'WINNER'" rule keeps the **first-loaded** copy and discards the
  later (usermap) one. So overriding a stock image/material name with a transparent
  usermap asset does **nothing** — both `specialty_*_zombies` and `i_t7_specialty_*`
  override attempts failed for this reason. (Earlier zone comments claiming "our usermap
  version wins by name" were **wrong** — corrected.)
- **The stock perk bar is a LUI widget** (`CoD.ZMPerksContainerFactory` → `LUI.UIList`
  "PerkList" → `CoD.PerkListItemFactory`) that shows a perk's icon only while the
  per-player model `hudItems.perks.<key>` is `> 0`.
- **Hide it from GSC by zeroing those models.** `_acc_lui::clear_stock_perk_hud()` writes
  all 9 `hudItems.perks.<key>` fields to 0 (`clientfield::set_player_uimodel` →
  `CodeSetUIModelClientField`, no script scoping — sets any named field). **Cosmetic
  only**: perk effects come from engine `SetPerk`, untouched. Field names verified vs
  `_zm_perks.gsh PERK_CLIENTFIELD_*` (aliases: staminup→`marathon`,
  fastreload→`sleight_of_hand`, deadshot→`dead_shot`,
  additionalprimaryweapon→`additional_primary_weapon`).
- **Zero flash:** `stock_perk_hud_suppressor()` clears on the stock `perk_acquired` notify,
  which fires the **same server frame** as the stock OWNED set with no wait between
  (`_zm_perks.gsc:756→780`) — so the client's end-of-frame snapshot never carries OWNED
  and the icon never appears on buy. `perk_state_watch`'s 0.25s clear re-asserts for the
  rarer unpause path (which does not fire `perk_acquired`).
- **Test:** dev `acc_dev_jugg_mega 1` (teal) / `2` (red); buy any perks → red row, no
  stock icons, no flash.

## Power-up bar — timed + instant power-ups (`CoD.AccPowerupBar`, 2026-06-15 / 2026-06-16)

A centered row of Ronan power-up icons, same `setImage(RegisterImage(...))` image rail as the perk
bar (no custom material). Driven by one 5-bit `accPowerupMask` clientuimodel (`_acc_lui.gsc`).

- **Timed power-ups** (bit 0 Insta-Kill / 1 Double Points / 2 Fire Sale) show **while active**.
  `powerup_state_watch()` (per-player 0.25s poll) reads the stock `level.zombie_vars` active flags
  and pushes the mask on change. The stock power-up icons for these 3 are suppressed
  (`suppress_stock_powerup_hud`, clears their `client_field_name` so the stock monitor drops them).
- **Instant power-ups** (bit 3 Nuke / 4 Max Ammo / 5 Carpenter / 6 Random Perk) have no active
  window, so they **flash for ~3s on pickup**. The server stamps `self.acc_flash_<name>_until =
  GetTime()+3000` and `powerup_state_watch` ORs the bit in while the stamp is live. Two signal paths:
  - **Dedicated** (Nuke / Max Ammo): `pickup_flash_watch()` per player listens for Max Ammo's
    team-wide `level notify "zmb_max_ammo_level"` (each player flashes itself) and Nuke's
    `nuke_triggered` on the grabber (which flashes ALL players, since power-ups are team-global).
  - **Generic** (Carpenter / Random Perk = `free_perk`): a level-once `powerup_drop_flash_watch()`
    listens for stock `level notify "powerup_dropped"` (fires per drop with the powerup ent), then
    watches that ent for its self-`"powerup_grabbed"` notify and flashes by `powerup.powerup_name`.
    Works for ANY powerup by name; fires only if/when those drops are enabled on the map.
- **Images:** `i_acc_powerup_{instakill,double,sale,nuke,maxammo,carpenter,randomperk}`.
  `CoD.AccPowerupBar` lays out N centered slots: slot i at `(i-(N-1)/2)*PITCH` from screen center.

## PaP tier icon — roman-numeral cyber shield (`CoD.AccPapTierIcon`, 2026-06-16)

Replaced the old bottom-right `"PaP TIER x/3"` GSC `createFontString` with a single small teal hex
roman-numeral shield (I/II/III) centered over the gadget HUD circle (bottom-right). Same image rail.

- **Data:** the existing `accPapTier` clientuimodel (0..3). `_acc_pap_levels::pap_hud_loop` now pushes
  the held weapon's `get_tier` on change (was drawing the font string); this is the same value
  `_acc_perk_info` pushes for the PaP info card, so the two writers never disagree. 0 = icon hidden.
- **Images:** `i_acc_pap_tier{1,2,3}`. Element shows only the icon matching the current tier.
- **Position:** right-anchored + bottom-anchored; `SIZE`/`RIGHT`/`BOTTOM` are eyeballed over the
  stock gadget art — **tune in-game** for a pixel-perfect center.

## Files

- `ui/uieditor/menus/hud/acc_hud.lua` — overlay menu + foundation banner + widgets
  (AccPerkCard, AccDmgNum, **AccPerkIcon** = Mega perk-icon indicator).
- `scripts/zm/zm_abandoned_cyber_city/_acc_lui.gsc` — server: register + open + set;
  `perk_state_watch()` drives the owned/mega masks.
- `scripts/zm/zm_abandoned_cyber_city/_acc_lui.csc` — client mirror register.
- `scripts/zm/zm_abandoned_cyber_city.csc` — `LuiLoad` in `main()`.
- `zone_source/zm_abandoned_cyber_city.zone` — 2 scriptparsetree + 1 rawfile +
  `image,` lines for the custom perk icons.
- `source_data/acc_perk_shaders.gdt` — custom perk-icon `image` assets (Ronan's
  Cyberpunk Shaders). Source PNGs under `source_data/acc_perk_shaders/_images/`.
- `tools/deploy_perk_shaders.ps1` — deploy the GDT + images to the Mod Tools
  `source_data/` + `gdtdb /update` (GDT lives outside the usermap sync).

## Source maps (cloned in tmp/, mined into docs/22)

- **MattFiler/zm_alien_isolation** — minimal standalone overlay (our template).
- **ohm-nabar/zm_building** — `t7hud_zm_custom.lua` override + clientuimodel widget.
- **ColDog5044/zm_countryside** — real perk-bar glow widgets (`hb21perklistitemfactory.lua`).
- **kelson8/bo3-Zombies-Test-Map** — GSC↔LUI menu round-trip (Cyberware-menu blueprint).
