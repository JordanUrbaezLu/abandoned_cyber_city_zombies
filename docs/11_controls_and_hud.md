# 11 - Controls and HUD

Living reference for the **shipped** controls and on-screen HUD. The HUD base is the
**Aetherium LUI kit** (adopted 2026-07-03), plus our slim additive `acc_hud` overlay,
the unified **gun-badge chip row**, and server-side health/boss bars. This doc is the
player-facing surface + the UI touchpoint inventory + the design palette. The LUI
**engineering** rules (clientfield bridge, render-safe primitives, the full-pool budget,
`SetValue` vs `SetText`) live in [docs/19](19_lui_pipeline.md) and are not duplicated here.

## Input Bindings

All standard BO3 controls are preserved. Custom inputs are additive.

### Stock BO3 bindings (unchanged)

| Action | Default binding (KBM) | Default binding (Gamepad) |
|---|---|---|
| Move | WASD | Left stick |
| Look / aim | Mouse | Right stick |
| Fire | LMB | RT |
| ADS | RMB | LT |
| Reload | R | X / Square |
| Jump | Space | A / X |
| Crouch | C | B / Circle |
| Prone | (hold C) | (click B / Circle) |
| Sprint | Shift | L3 |
| Slide | (Sprint + Crouch) | (L3 + B / Circle) |
| Melee | V / F | R3 |
| Grenade (lethal) | G | RB |
| Grenade (tactical) | Q | LB |
| Swap weapon | 1, 2, 3 / Mouse wheel | Y / Triangle |
| Use / interact | F / E | X / Square |

### Custom inputs (map-specific)

| Action | Binding | Notes |
|---|---|---|
| **Weapon Ability** | **ADS + Melee chord** (RMB + V on KBM / **LT + R3** on gamepad) | Not a rebindable key. `_acc_weapon_abilities::player_ability_listener` polls `AdsButtonPressed() && MeleeButtonPressed()` (0.05s) and fires the held weapon's ability class, then a 0.5s debounce. BO3 has no console command that emits a script notify on a player, so an earlier `bind h notify acc_ability` scheme could never work — the chord is the shipped input. Ability resolves via `acc_weapon_variants::true_base` so it survives PaP and Mega twins; cooldowns run holstered too. <!-- TODO(acc-input): a real LUI keybind was the planned Phase-4 replacement (_acc_weapon_abilities.gsc:160,187). --> |
| **Third-person toggle** | Pause menu → "Third Person" option | Aetherium StartMenu option `ui_menu_option_third_person`; `_zm_aetherium_hud::menu_option_third_person_handler` (`_zm_aetherium_hud.gsc:605`) calls `setclientthirdperson(1, 120, 30)` (`_zm_aetherium_hud.gsc:626`). |

### Contextual interactions (stock Hold-to-use)

Every device below uses the **stock interact** (Hold `[{+activate}]` — default **F / Square**).
No custom keys; the interaction is the world trigger you look at.

| Device | Location | Effect |
|---|---|---|
| Perk machine | per zone | Buy perk; Mega upgrade prompt is Mega-aware (bottle cost). |
| Pack-a-Punch | Lab | Our tiered PaP (T1-T3 scaling cost; `_acc_pap_levels`). |
| Mystery Box | 6 locations (roaming) | Stock box; **box-only** weapon distribution (large arsenal). One active at a time across 6 chest nodes (`acc_box_market/corp/roof/plaza/lab/vault`). |
| Wallbuys | per zone | Stock name + price via Aetherium cursor hint (`PromptWallBuy`). |
| Buyable doors | 13 doors | `zombie_door` triggers (`script_flag enter_*`). |
| Power switch | Corp (Bus Station) | Stock power; also the Emergency Drop trigger (below). The Vault switch was removed 2026-06-18 — the map ships **one** switch. |
| Overclock terminal | Lab | Shard-spend **weapon-upgrade** UI — the live upgrade path (`_acc_overclocks`, model `p7_zm_sta_dragon_network_data_terminal`). The Cyberware kiosk/tree is **disabled by default** (gated behind `acc_cyberware_on`, default 0) and is not spawned. |
| Exo Suit station | trench | Per-player depth-gate; cancels the per-layer trench slow (docs/29). |
| Armory rack | Plaza upper room | Pooled-weapon rack + bottle→random-reward exchange. |
| Jukebox | North trench room | Random song, 2 Data Shards + 1000 pts (replaced the EE-song teddy bears). |
| Glitch Altar | trench rooms | Data Shard gamble. |
| The Exchange | transfer vault | `_acc_transfer` currency/item transfer. |
| Reactor | pit | Reactor Surge climax event (docs/30). |
| Hack Terminal | Bus Station | Side event; 500-point cost (`_acc_events_hack`). |
| Boss-item world pickup | at a boss corpse | **Hold to grab** — `trigger_radius_use`, 64u radius (`ACC_ITEM_PICKUP_RADIUS`), `SetHintString("Hold [{+activate}] to grab <id> - <name>")`. Free-for-all; a duplicate auto-converts to 3 Data Shards on grab. |
| Emergency Drop | on an active power switch | Hold to call a drop, 3-Shard cost; piggybacks the power-switch triggers (`_acc_emergency_drop::watch_power_triggers`). |

> **Retired:** the "Vault Overload" side event (its `acc_overload_terminal` trigger + point
> struct) was removed 2026-07-07 — `acc_events_overload::init()` is commented out in
> `_acc_main.gsc:199`. Do not document it as an interaction.

### Interactable-station holo shimmer (2026-07-17, `_acc_interact_glow`)

**Every custom station mesh carries an animated cyan hologram shimmer rendered ON the model**
— the "you can USE this" affordance (user: players couldn't tell station props from decoration;
item drops already glow via FX, stations needed better). Not an FX: the engine's
**duplicate-render** pass re-draws the tagged entity's mesh with a holo material, the exact
mechanism behind the AW box's cyan reveal flash — so *cyan holo = interactable* is one language
map-wide, box included. v4 state (2026-07-17, after a techset deep-dig —
`share\raw\techsetdefs_stable\specialty\ghost.techsetdef` is the shader's ground truth):

- **Dim:** custom clone `mc/acc_dr_fx_holo_dim` (`acc_aw_holo_dim.gdt`, install-side next to
  the gold/green box clones) with `cg02` ("SceneTint") + `colorTint` scaled **×0.35** — the
  proven ghost-techset color path (it's how the box's gold/green recolors work). `scaleRGB`,
  `flicker*`, and `colorMap` swaps are **inert/unread** on this techset (v2+v3 live tests) —
  don't retry them.
- **Pulse:** the **server blinks the `acc_interact_glow` clientfield** — resting state is NO
  glow; every 4.0s the station gives one brief 0.7s holo flash (user 2026-07-17: "No glow for
  4 seconds"; random phase per station). The box holo's own live-proven CF transition path; no
  material-side pulse lever exists. Timing = the two `ACC_GLOW_*_TIME` defines in the `.gsc`.
- **Discovery semantics:** the flash is a "you haven't used this yet" beacon — it **stops
  permanently (run-scoped, team-global) on the station's first SUCCESSFUL use** (user
  2026-07-17: implant actually installed, tier actually bought, pool actually changed...).
  Denied presses don't clear it. Each owning module calls `acc_interact_glow::glow_off(model)`
  in its success branch; the Implant Bench clears per PAD, the vault per 4-pool station
  (pre/post pool snapshot because its op helpers deny internally with no return value).
- **Known limit (Exo pod lower half):** the ghost techset is `"lit transparent"` — scene
  lighting (plus possibly baked vertex AO) modulates the additive holo, so a shadowed lower
  body shows ~nothing. Intrinsic to the family; `hud_outline_*`/`sonar_rim` (replace-blend
  keyline-buffer shaders) and `hacked` (also lit) are unusable in-scene. Real fixes if wanted:
  swap the exo station to a mesh that reads well with top-weighted glow, or author an unlit
  `emissive_passthrough_transparent(_scroll)` overlay material (scrolling scanline texture =
  holo look without the lighting dependency).

- Recipe: 1-bit `scriptmover` clientfield `acc_interact_glow` (GSC sets it on the station's
  `script_model`) → `.csc` callback flips the ent's DR flag on filter id **20**
  (`set_dr_filter_framebuffer_duplicate`; ids 9/10/30-32 taken). LOCKSTEP registration in both
  VMs, `_acc_tripletake` autoexec pattern.
- Tagging is **explicit** — `acc_interact_glow::glow_on( ent )` at the spawn site (13 sites, 11
  modules). A model-name scan was rejected: the deco modules spawn the *same* meshes as scenery
  (5 deco generators, deco pod/terminals/ATM), which would false-shimmer. `glow_off( ent )` exists
  for consumed/disabled stations (unused v1).
- Shimmering stations: Exo pod, Implant Benches, Cyberware kiosk, Armory cabinet + Bottle
  Exchange, Glitch Altar slab + Paradise box, Leaderboard terminal, Neural Expansion console,
  Overclock terminal, 4 Exchange ATMs, Reactor plinth, Jukebox. Deliberately NOT tagged: perk
  machines / PaP (recognizable vending affordance), AW box (own holo states), wallbuys, doors.

Three cooperating layers draw the combat HUD:

1. **Aetherium LUI kit (the base HUD).** Adopted 2026-07-03; replaces the stock
   `T7Hud_zm_factory` menu wholesale. Gated by the hardcoded master flag
   **`level.acc_aetherium_hud`** (`_acc_lui.gsc:56`, `true`); every module reads it (a
   `false` restore is the 3-step recipe in that file's header). Ships a **custom TTF font**
   (`fonts/ltromatic.ttf`) — the single biggest "cheap tell" the old stock font left is gone.
   Widgets (`ui/uieditor/widgets/HUD/AetheriumWidgets/`, wired in `AetheriumHud.lua`):
   round counter, perks container, power-ups container, player-info panel, party-players
   roster, weapon loadout, GobbleGum, kill feed, scoreboard, ZM cursor hints.
2. **`acc_hud` overlay (our map-unique widgets).** A standalone additive overlay opened
   per-player (`player OpenLUIMenu("acc_hud")`), never a stock override — so it can't break
   HUD load. It carries the three widgets the kit doesn't: **damage numbers**, the
   **HOSTILES round-progress bar**, and the **gun-badge chip row**
   (`ui/uieditor/menus/hud/acc_hud.lua`). Several older classes (`AccPerkCard`,
   `AccPerkBar`, `AccPowerupBar`, `AccAmmoBlock`, `AccEquip`, `AccShardIcon`) are **retired
   but kept as restore paths** — documented workarounds, do not delete them.
3. **Server hudelems (GSC).** The player HP bar, the boss HP bar + 3D nameplate, and the
   equipped-boss-item lines are legacy `hud::` elements drawn from GSC
   (`_acc_health_bars.gsc`, `_acc_boss_items.gsc`) because there is no LUI player-health
   model and the clientuimodel pool is full (docs/19).

### Perk icons, power-ups, round counter, ammo (kit-drawn)

- **Perk icons** — `AetheriumPerksContainer`, but **rewired to our data**: it reads our
  `accOwnedMask` / `accMegaMask` clientuimodel bitmasks (`_acc_lui::perk_state_watch`) and
  Ronan's Cyberpunk-Shader base/Mega icons, so a Mega'd perk shows its teal variant.
- **Power-ups** — `AetheriumPowerupsContainer`, drawn from the **stock** power-up
  clientfields (our old suppressor + `AccPowerupBar` are disabled behind the master flag).
- **Round counter** — `AetheriumRoundCounter`: the vanilla **image-based** round display,
  top-right (`ZmRndContainer`, ~50px from the right edge). The earlier "recolor the round
  counter teal by overriding `RoundStatus.lua`" plan was **abandoned** — no such file ships,
  and overriding a stock HUD *menu* risks a non-loadable `.ff` (docs/19).
- **Weapon / ammo / equipment** — `AetheriumLoadout`, bottom-right plate.
- **Riot-shield equipment slot** — `AetheriumLoadout` (added 2026-07-15): a satellite slot
  on the loadout **orb's lower-right rim**, plate tilted via `setZRot` to follow the curve
  (the grenade slot owns the upper-right rim; AAT icon + badge row own the lower-left). All
  geometry derives from the `SHIELD_*` constants block (orb center / angle / radius /
  rotation) — screenshot-pass tuning is a 1–2 number tweak + `-GscOnly` rebuild. Visible
  while the
  Rocket Shield implant's `zod_riotshield` is granted — lit plate + `riotshield_zm_icon`
  tinted by remaining shield health (blue → orange → red); while the shield is **destroyed
  but the implant is still benched** (60s regrant window) it shows the empty plate + dim
  icon instead of vanishing; hidden entirely with no implant. Wiring (the part the kit
  shipped broken — its `AetheriumPlayerInfo` shield bar is dead code, left dead on purpose):
  `zmInventory.shield_health` / `hudItems.showDpadDown` are server `set_player_uimodel`
  bridges with **no client node until first write**, so consumers must `Engine.CreateModel`
  (never `GetModel`); stock's destroy path writes ONLY `showDpadDown=0`, so one refresh
  subscribes to every gate model (+ `acc_implants` nibble decode for the regrant state).
- **Riot-shield health bars** (2026-07-15, user: "good to know if your teammates have one
  and the health of the shield"): three shield surfaces total. (a) The gun-HUD slot above;
  (b) the **own player card's** blue→gold→red shield bar above the HP bar
  (`AetheriumPlayerInfo` — the kit shipped it half-dead, now on the fixed dual-model
  wiring); (c) **teammate mini-bars** — a thin bar above each party row's health bar
  (`AetheriumPartyPlayers`), fed by a new world-scope broadcast `player_shield_0..3`
  (5 bits: 0 = none, 1..31 = health; registered in gsc+csc lockstep after `player_exo`,
  pushed by `player_currency_watch`). Server reads shield health via the
  **`DamageRiotShield(0)` hack** — a zero-damage call returns the remaining engine pool,
  which has no other getter. Shield data is otherwise personal-scope, so without this
  broadcast teammates could never see it.

### Currencies (Data Shards / Mega Bottles / Exo Suit)

Rendered in the **Aetherium PlayerInfo panel** (bottom-left), not as loose corner text.
Each rides a private **toplayer** clientfield → UI model: `acc_shards` (10 bits, ≤1023),
`acc_mb` (5 bits, ≤31), `acc_exo` (4 bits, ≤15), plus `acc_maxhp` (9 bits) for the real
max-HP readout (`_zm_aetherium_hud.gsc:92`, `AetheriumPlayerInfo.lua`). In **co-op** the
same three values are also broadcast **world-scope** (`player_shards_N` / `player_mb_N` /
`player_exo_N`, `_zm_aetherium_hud.gsc:67`) so the `AetheriumPartyPlayers` roster shows each
teammate's shards, bottles and Exo level. `player_currency_watch` (0.25s change-guarded
poll) feeds both lanes and clamps to the field widths. Mega Bottles read 0 until your first
boss — the panel simply shows the count.

### The gun-badge chip row

One right-anchored row of uniform chips **under the ammo readout** (`acc_hud.lua`
`CoD.AccGunBadgeRow`), showing every enhancement of the **held** weapon. Rightmost chip is
priority 1; further badges pack **leftward** and the row re-anchors gap-free as chips come
and go. Two data lanes feed one row:

- **Tier badges** (value-bearing) ride their existing clientuimodels — `accPapTier` (0-3,
  PaP tier shields) and `accOcTier` (0-10, Cyberware Overclock level). No new fields (the
  pool is full); the row just re-consumes what the PaP/OC report cards already push.
- **Flag badges** (on/off) share ONE `acc_badges` toplayer bitmask
  (`_acc_gun_badges.gsc`, 6 bits): **bit 0 = MULE** (the gun Mule Kick removes on a down —
  swap-stable via the acquisition-order override), **bit 1 = TURBO** (Turbocharger implant +
  holding a Havoc), **bit 2 = PLASMA** (Plasma Generator implant + holding an energy weapon),
  **bit 3 = BRZ** (Berzerker implant + holding a melee weapon it speeds up — Leviathan Axe /
  Action Figure; the knife-bash surface deliberately doesn't light it, it would pin on always).
  A per-player 0.25s poll (`badge_watch`) recomputes the whole mask from a **predicate
  registry**, so it is self-correcting on any weapon swap / perk gain / twin reform.

**Adding a badge** is a 3-line recipe (predicate + `register_badge(bit, &pred)` + an
`ACC_GUN_BADGES` entry) — never a new one-off widget or field. See the `_acc_gun_badges.gsc`
header. Chips use full-bleed 5:7 pennant PNGs (`i_acc_*`); text chips get the navy plate.

### HOSTILES round-progress bar

Salvaged from the round-progress research (docs/11). The shipped form is a **top-right
horizontal bar** (`acc_hud.lua` `CoD.AccRoundRing`), **full at round start and draining
right-to-left** as the round's zombies die, teal → magenta as it empties. It is a layered
cyberpunk meter built **entirely from render-safe `CoD.TextWithBg.Bg` rectangles** (no
custom material): outer cyan halo, navy track, the teal→magenta drain fill, segment
notches, a bright "drain front" sliver riding the fill's moving left edge, a top accent
line, four corner targeting brackets, and a small **"HOSTILES"** caption (the old `pct%`
readout was removed, user 2026-06-17). The fill + sliver **slide** to each new value via a
250ms LUI keyframe tween (`completeAnimation → beginAnimation`), matching the ~0.25s server
push so steps chain into a continuous drain.

Data path: one `accRoundRing` clientuimodel int (7 bits; `_acc_lui.gsc:100`) = fill percent,
**clamped 0-100** (`set_round_ring` never pushes above 100; the 7-bit field width just spans
0-127). There is **no hide sentinel** — the bar is always visible. `_acc_lui`'s `round_ring_watch` tracks the "full"
denominator as a **high-water-mark (peak) latch**: `total` resets to 1 each new round, then
grows to the peak of `remaining = alive + level.zombie_total` seen that round
(`if ( remaining > total ) total = remaining;`, `_acc_lui.gsc:228`), and the fill is
`remaining / total * 100`. A per-player `round_ring_watch` (0.25s poll) pushes the fill on change; the bar
is **always visible** — there is no boss-round or no-wave hide.

> The earlier **radial ring** design (a stock `hud_objective_circle_meter` material driven
> by `setShaderVector`) was the first attempt and is **abandoned** — that meter draws in
> full-screen space and never fit our corner. The shipped bar above is the truth; docs/11
> keeps the radial recipe only as a deferred-upgrade footnote.

### Damage numbers

Crosshair-anchored, drawn by `acc_hud.lua` `CoD.AccDmgNum` from a pooled set of text
elements. A single batched number appears just above the crosshair (reads as damage on the
zombie you're aiming at); sustained fire accumulates into one steadily-updating number and
it rises + fades ~0.35s after the last hit. **Amber** `(1.0, 0.88, 0.25)` for normal hits,
**teal** `(0.20, 0.95, 0.85)` when the batch landed a headshot (sticky-OR'd across the
batch); headshots render 25% bigger. Encoding: the `accDmgNum` clientuimodel int (18 bits)
packs `dmg*4 + headshot_bit(2) + parity(1)`; the parity bit flips each push so an identical
number still re-pops (decoder `acc_hud.lua:471`). Over-entity floating text was rejected (it
needs overriding `CoD.Waypoints`).

### Player & boss health bars, nameplate

Server hudelems in `_acc_health_bars.gsc`. The **player HP bar** sits bottom-left
(`hud::createBar`); it **widens** with your real max HP (Jugg/Mega tiers rebuild the bar,
since `createBar` bakes the width) and the fill recolors by Jug tier. The **boss HP bar +
3D nameplate** appear on the `acc_boss_spawned` notify and hide on the boss's death
(`boss_bar_listener`). Both the player and boss bars **slide** to new values via
`acc_set_bar_smooth()` (a `scaleOverTime` glide on the stock fill, ~0.25s) instead of
snapping — the same motion grammar as the HOSTILES bar.

### Equipped boss-item indicator

**Full PNG since 2026-07-12** (user pack `cyber_city_implant_hud`, v4 962×176 "compact" bars): the
left HUD draws **four always-on bars** (3 slots + a HOLDING bar; big `IMPLANT N` title only) with
each item's **glyph emblem overlaid** on the bar's right window when filled — the LUI widget
`CoD.AccImplantRow` (`acc_hud.lua`, bars 230×42 at x 32 from y 220, stride 48; full recipe docs/19).
The **pause-menu Implant Panel** (`AetheriumStartMenu.lua`) draws the same bars at the **exact same
coords so it OVERLAPS/covers the in-game bars while paused**, with the name/desc text kept to the
right of each, and the amber CARRYING line. Both decode the 16-bit `toplayer` clientfield
`acc_implants` (four 4-bit `item.num` nibbles slot1/2/3/carried, pushed by
`_acc_boss_items::push_implants_clientfield`, registered in `_zm_aetherium_hud.gsc/.csc`, see
docs/09). `display_for()` (pickup prompt + messages) stays name-only. The old **server hudelem
stack is GONE** (`sync_items_hud` is now just the clientfield push) — up to 4 per-client
hudelems returned to the shared pool, a real co-op win. This is the persistent sign of what
you're holding.

### Pause-menu OBJECTIVE tracker + PERK reference (2026-07-13; milestone ladder 2026-07-15)

Below the implant panel, the pause menu (`AetheriumStartMenu.lua`) uses its free left column
(x32-790, y392-682) for two glance panels the space-starved in-game HUD can't fit:
- **OBJECTIVE** — a "what next" run-phase hint plus a dynamic progress line and a red boss
  warning. The phase ladder is **milestone-driven** (2026-07-15, replaced the plain round-8
  split): power off → build loadout ("prepare for the Round 9 BOSS") → **one state per trench
  descent gate** ("Bank souls below to open the door to Trench Level 2/3/4/5", indices 3-6) →
  **Maw soul quota → pay the Paradise gate → gather at the gate** → gate open → onslaught →
  complete (indices 1-12). Rides the 4-bit `acc_objective` **toplayer** clientfield, computed
  level-globally by `_acc_lui::acc_compute_objective` from `acc_paradise_open/onslaught/won`, the
  `power_on` flag, the **real `_acc_abyss_doors` state** (soul-door open count,
  `acc_hub_souls_complete`, the shards/points pools) and round — correct for every co-op client.
  **TOPLAYER-BUDGET NOTE (2026-07-15 incident):** the first version of this feature added a 16-bit
  `acc_objective_detail` toplayer field and **broke map load** (the toplayer pool is FULL — stock
  `visionset_lerp` failed to register, docs/19). Re-landed with zero pool growth: the 4-bit widen
  is paid for by `acc_box_gun` 6→5 (the hot-fix ALSO shaved `acc_badges` 6→4, but that was surplus
  — and it orphaned the HICAL/WARHD chips at bits 4/5, so `acc_badges` is back to 6), and the
  **detail line** now reads the
  `acc_obj_detail` **dvar** (`a + b*128`, +1 so 0 = no data): loadout = zones opened (+ perk count
  bit-counted client-side from `accOwnedMask`); descent = souls % toward the gate; Maw = soul
  quota %; pay = Shards + points remaining; gather = survivors at the gate a/b (published by
  `hub_gather_watch`). Host-accurate; remote co-op clients see only the client-side parts (never
  wrong numbers). The **red BOSS-round warning** ("BOSS ROUND NEXT - gear up NOW" / "BOSS ROUND -
  it is hunting you") is fully client-side off the `gameScore.roundsPlayed` model (= round + 1):
  fires on rounds ≡ 8/0 mod 9 (the roster cadence 9/9 hardcoded in `AccBossWarnState`; the cadence
  dvars are manual test knobs only), suppressed once Paradise opens (phase ≥ 10). The perks block
  shifted down (header y494) to keep the section gap.
- **PERKS** — your owned perks and what each does; Mega'd perks show the Mega upgrade in teal. Reuses
  `CoD.AetheriumPerks` + the `accOwnedMask`/`accMegaMask` masks — no new data wire.

### Kill feed

The map **does** have a kill feed now (this reverses the old "we don't have one" note). The
`AetheriumKillFeed` widget renders it, but entries are **sent from our own scoring** —
`_acc_points::send_kill_feed → LuiNotifyEvent(&"score_event", …)` at each payout site
(`_acc_points.gsc:523`), carrying the **real paid points** (our custom economy: base
70/110/100, co-op split, DP scaling, ledger bonus), keyed by **bare `KF_*` strings** in
`localizedstrings/zm_aetherium.str` (the T7 compiler auto-prepends `ZM_AETHERIUM_`). The
kit's own `zombie_death_callback` is kept **dormant** because it computed feed values from
stock scoring formulas that don't match this map.

**Feed text colors (user 2026-07-11):** regular kills (normal/melee/burned/elimination) =
**yellow** `(0.92, 0.94, 0.17)`; **Critical Kill = cyan/teal** `(0.20, 0.95, 0.85)` — the SAME
teal as the headshot damage numbers (`ACC_DMG_COLOR_HS` in `acc_hud.lua`), so crit feed text and
crit damage numbers read as one signal. AAT kills (Electric/Blast Furnace/Fireworks/Thunderwall/
Turned) keep the same yellow as regular kills. (Before: crits yellow, regular white.) All in
`SetKillTypeColor`, `AetheriumKillFeed.lua`.

### HUD elements we deliberately DON'T have

- **Minimap** — no. Zombies convention; would undercut zone-memorization skill.
- **Enemy HP bars on every zombie** — no (that is what the Targeting Visor boss item unlocks).
- **Waypoint arrows** — no.
- **Persistent combo counter** — no.
- **Cyberware "stack" widget / weapon-tier text line** — never built as originally sketched;
  the Overclock level and PaP tier now render as chips in the gun-badge row instead.

## Design language (Cyber City)

One themed accent layer over a clean combat center. **teal = power, magenta = danger**
(magenta lerps in as "decay"), and **only state changes animate** — premium reads as
*consistency + restraint + motion*, not complexity. The shipped palette is one table,
`ACC_PAL` in `acc_hud.lua:27`, and every widget draws from it (LUI `setRGB` floats 0-1):

| Token | RGB | Use |
|---|---|---|
| **glass** | `0, 0.035, 0.085` | dark-navy panel base (the universal plate / bar track) |
| **cyan** | `0.20, 0.75, 1.00` | primary system accent (frames, strips, brackets) |
| **teal** | `0.20, 0.95, 0.85` | good / owned / upgraded / headshot / bar full |
| **violet** | `0.72, 0.45, 1.00` | PaP / Mega reward tier |
| **amber** | `1.00, 0.88, 0.25` | money / value / normal damage numbers |
| **danger** | `0.90, 0.20, 0.55` | low / empty / boss / lockdown / bar drained |

- **Layout zones (avoid collisions):** top-right = round counter + HOSTILES bar;
  bottom-left = player health + Shards/Bottles/Exo + implant lines; bottom-right = weapon
  loadout + gun-badge row; center = crosshair + damage numbers; contextual center = cursor
  hints / device prompts.
- **Motion:** fade in/out (~0.15s), bar/health **slides** (250ms tween), damage-number
  rise+fade. Subtle; no jarring pops. Dark backing plates aid contrast against the map's
  intentionally dark color grade.
- **Render constraints (why it looks the way it does):** custom full-screen shaders
  (blur/CRT/bloom) and custom 2D HUD materials are **not** feasible in a usermap — the HOSTILES
  bar and every plate are built from tinted rectangles, and icons are plain `RegisterImage`
  PNGs, on purpose (docs/19, docs/20).

## UI touchpoint inventory (shipped renderer)

The map's UI touchpoints and what actually draws each one today:

| # | Touchpoint | Shipped renderer |
|---|---|---|
| 1 | Perk / PaP purchase | Aetherium ZM cursor hint (`PromptPerks`, Mega-aware w/ bottle cost). Our `AccPerkCard` walk-up report card is retired. |
| 2 | Wall buy / box / door / power prompts | Aetherium cursor hints (`PromptWallBuy` / `PromptMysteryBox` / `PromptDoors` / `PromptPowerSwitch`). |
| 3 | Perk icons | `AetheriumPerksContainer` (our `accOwnedMask`/`accMegaMask` + Ronan base/Mega art). |
| 4 | Power-ups | `AetheriumPowerupsContainer` (stock power-up clientfields). |
| 5 | Round counter | `AetheriumRoundCounter` (image round display, top-right). |
| 6 | Weapon / ammo / equipment | `AetheriumLoadout` (bottom-right). |
| 7 | Currencies (Shards / Bottles / Exo) | `AetheriumPlayerInfo` panel + `AetheriumPartyPlayers` (co-op teammates). |
| 8 | Player + boss HP + nameplate | server hudelems (`_acc_health_bars.gsc`, sliding bars). |
| 9 | Held-weapon status (PaP / OC / MULE / TURBO / NUKE / BRZ) | `acc_hud` gun-badge row (`CoD.AccGunBadgeRow`). |
| 10 | Round progress | `acc_hud` HOSTILES bar (`CoD.AccRoundRing`). |
| 11 | Damage numbers | `acc_hud` (`CoD.AccDmgNum`). |
| 12 | Kill feed | `AetheriumKillFeed` + `_acc_points::send_kill_feed`. |
| 13 | Equipped boss items (implants + carry) | server hudelem stack (`_acc_boss_items::sync_items_hud`). |
| 14 | Weapon-ability activation / cooldown | `iprintln` feedback ("Activated: …" / "on cooldown"). |
| 15 | Event warnings (Lockdown / Decontamination / Reactor / Glitch Altar) | server toast/banner hudelems + `iprintlnbold`. |
| ~~—~~ | ~~Rampage Inducer device~~ | removed 2026-06-14 — replaced by the per-round zombie-speed curve (no UI). |

## Accessibility

- **Colorblind:** we lean on both **color AND shape** (perk/badge icons carry distinct art,
  not just a hue), and respect BO3's global colorblind toggle where it applies.
- **Text size:** HUD text respects stock scaling; the custom TTF is used at readable sizes.
- **Reduced motion:** the only animations are short slides/fades; none are seizure-risk.
- **Out of scope:** screen-reader / TTS (BO3 has none), audio-visualization-for-deaf-players,
  one-handed schemes — stock BO3 doesn't ship these and we don't add them.

## Tuning levers

- **Element geometry** is a small block of local consts at the top of each `acc_hud.lua`
  widget (`ACC_BAR_*`, `ACC_GUN_BADGE_*`, `ACC_DMG_*`) — shuffle layout by editing those and
  rebuilding `-GscOnly` (rawfile Lua, no geometry). Most positions are still tuned in-game by
  screenshot pass.
- **Master HUD flag** `level.acc_aetherium_hud` (`_acc_lui.gsc:56`) — the one switch between
  the Aetherium base HUD and the pre-Aetherium restore (3-step, header-documented).
- **Dev mode** is the single hardcoded `level.acc_dev` gate — never a runtime HUD dvar
  (docs/22_flags_reference.md). Debug banners are gated on `level.acc_dev` only.

## Related docs

- [docs/19](19_lui_pipeline.md) — LUI engineering (clientfield bridge, render-safe
  primitives, pool budget, `SetValue`/`SetText`). **All LUI rules live there, not here.**
- [docs/11](11_controls_and_hud.md) — HOSTILES-bar research + the deferred
  radial-ring recipe.
- [docs/19_lui_pipeline.md](19_lui_pipeline.md) — the modernization plan (largely
  superseded by the Aetherium adoption; north-star palette + motion grammar still current).
- [docs/20](20_atmosphere_and_materials.md) — why custom materials/fonts/shaders are constrained.
- [docs/04](04_weapons.md) / [docs/10](10_perks.md) — the systems behind the ability chord,
  PaP tiers, and Overclock levels the badges surface.
</content>
