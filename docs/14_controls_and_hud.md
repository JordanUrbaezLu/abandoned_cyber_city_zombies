# 14 - Controls and HUD

Input bindings, HUD elements, and LUI implementation plans.

## Input Bindings

All standard BO3 controls are preserved. Custom bindings are additive.

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

### Custom bindings

| Action | Default binding | Notes |
|---|---|---|
| **Weapon Ability** | **H** (KBM) / **D-pad Down** (Gamepad) | TODO(acc-input): final binding TBD during Phase 4 LUI work. Community-standard bind is `bind h notify acc_ability` via console. Current scaffold listens for `"acc_ability"` notify event; any binding that emits that works. |
| Cyberware Kiosk interaction | Hold F on the kiosk (Plaza) | Stock interact, Cyberware handled contextually |
| Overclock Terminal interaction | Hold F on the terminal (Lab) | Stock interact |
| Pack-a-Punch interaction | Hold F on the PaP machine (Lab) | Stock interact, our code multiplies to L1-L5 |
| Hack Terminal activation | Hold F on terminal (Bus Station) | 500-Point cost |
| Vault Overload activation | Hold F on terminal (Vault) | 1000-Point cost |
| Emergency Drop call | Hold F on active power switch | 3-Shard cost |
| Boss item pickup | Walk within 64u of item entity | Auto-pickup unless inventory full |
| Unequip boss item | Hold F on Cyberware Kiosk with context | Drops to ground for 30s |
| Wonder weapon craft | Hold F on craft terminal (Lab / Vault) | 5-Shard + side event gate |

### Input implementation status

- **Phase 3**: abilities activated by a console `bind` that emits `notify acc_ability`. Functional but requires user setup.
- **Phase 4**: LUI binding screen in the map's pause menu; player can pick any key; persisted to config.
- **Phase 4**: full rebind-all-actions support if stock BO3 doesn't surface it cleanly.

## HUD Elements (all on-screen at once, during gameplay)

Stock BO3 zombies has a base HUD (round, points, crosshair, perks, weapon/ammo). We add several custom elements.

### Stock HUD elements (unchanged)

- **Round counter** - the stock round number is recolored to **teal** (user 2026-06-17) by
  OVERRIDING its own LUI widget: we ship `ui/uieditor/widgets/hud/RoundStatus.lua` at the stock
  path (redefining `LUI.createMenu.RoundStatus`), so the engine draws our version. It is the stock
  round-counter structure with only `DefaultColor` changed dark-red→teal, so the native
  chalk/round-up animation is preserved. The zm_building technique (rawfile only, no LuiLoad). This
  replaced an earlier overlay+mask attempt (`CoD.AccRoundNum`, now removed). docs/42, docs/22.
- **Points counter** - lower-left.
- **Perk icons** - above points (stock 4-slot row).
- **Weapon + ammo** - lower-right.
- **Grenade counts** - lower-right, above weapon.
- **Crosshair** - center.
- **Damage vignette** - red screen edges on low HP.
- **Revive prompts** - on-screen when a downed teammate is nearby.
- **Mystery Box interaction HUD** - on-screen when near box.

### Custom HUD elements (ACC-specific)

Rendered via LUI; implementation deferred to Phase 4. Layout sketch below.

```
+-----------------------------------+
|                      ROUND 12     |  <- stock
|                                   |
|         [crosshair]               |
|                                   |
|  CW:OC1-Oc1-..                    |  <- Cyberware stack (bottom-left)
|  Items: [Boots] [Shroud]          |  <- Equipped items (bottom-left, above CW)
|  Tier:3/5 PaP:L4   [H:12s]        |  <- Active weapon status + ability CD
|                                   |
|  Shards: 14    Points: 8,420      |  <- Currency row (lower-left)
|  [Perks]                          |  <- Stock + custom perks
+-----------------------------------+
```

#### 1. Data Shard counter

- **Position**: lower-left, adjacent to the Points counter.
- **Format**: `Shards: 14`.
- **Updates**: real-time (via the `acc_data_shards` clientfield bridge in `_acc_data_shards.gsc`).
- **Visual**: small neon-blue shard icon + number. Pulses briefly on gain/spend.
- **Phase 3 fallback**: `iprintln` text ("+1 Data Shard"). Works but ugly.

#### 1b. Mega Bottle counter

- **Position**: lower-left, adjacent to the Data Shard counter.
- **Format**: `Bottles: 2`.
- **Updates**: real-time via `acc_mega_bottles` clientfield.
- **Visual**: small golden flask icon + number. Glows briefly on gain / consume.
- **Phase 3 fallback**: `iprintln` text ("+1 Empty Mega Bottle") on boss drops and "-1 Empty Mega Bottle (Mega'd <Perk>)" on consumption.
- **Hidden if count is 0** (avoid HUD clutter for players who haven't seen their first boss yet).

#### 1c. Equipped boss-item indicator

- **Position**: top-left, stacked directly under the Data Shards line (`TOP_LEFT` 16, 68).
- **Format**: `ITEMS 1 - Neural Boots | 3 - Targeting Visor` — each entry is `id - name`, where `id` is the item's stable numeric ID (1–6). Up to 2 equipped slots, ` | `-separated.
- **Updates**: on equip / unequip / swap (`_acc_boss_items::sync_items_hud` — a server-side `createFontString`, mirroring the Data Shards hudelem; `id - name` comes from the shared `display_for()` helper, also used by the world pickup prompt + message).
- **Hidden when no items are equipped** (alpha 0).
- **Implemented** (2026-06-17): replaces the previous transient `iprintln("Picked up: …")`-only feedback, which left no persistent sign you were holding an item.

#### 2. Cyberware stack indicator

- **Position**: lower-left, above currency row.
- **Format**: 3 slots, filled left-to-right as tiers unlock. Each slot shows the branch icon (Overclock / Subroutine / Reflex) + tier number.
- **Example**: `[OC-1] [SR-2] [  -  ]` means Overclock T1 + Subroutine T2, Tier 3 empty.
- **Tooltip on hover** (Phase 4+): shows full node name + effect.
- **Phase 3 fallback**: `iprintln` on cyberware-purchased event.

#### 3. Current weapon status

- **Position**: below the crosshair, center-bottom or lower-right adjacent to stock ammo.
- **Format**: `Tier 3/5  PaP L4  [Ability: 12s]`.
- **Content**:
  - Current weapon tier (T0-T5).
  - Current PaP level (L0-L5).
  - Active ability name + cooldown (if on CD) or "Ready" indicator.
- **Color state**:
  - Gray = not tiered / not PaP'd.
  - White = ability ready.
  - Orange = ability on cooldown (with seconds remaining).

#### 4. Boss item slots

- **Position**: lower-left, above the Cyberware row.
- **Format**: 2 slot icons, filled or empty.
- **Example**: `Items: [Neural Boots] [Ghost Shroud]` or `Items: [Neural Boots] [ - ]`.
- **Tooltip on hover** (Phase 4): shows full item name + effect.
- **State indicators**:
  - Kinetic Battery shows charge progress (e.g. `[Battery 8/10]`).
  - Ghost Shroud shows cooldown when on CD (e.g. `[Shroud 45s]`).

#### 5. Objective prompts (Hack Terminal / Vault Overload stages)

- **Position**: upper-center, below the round counter.
- **Format**: `HACK STAGE 2/3: Kill 3 Shielded elites in 60s [2 / 3, 0:42]`.
- **Lifecycle**: appears when event activates; disappears on success/failure.
- **Color**: yellow during active event; green flash on stage complete; red flash on timeout.

#### 6. Boss health bar

- **Position**: upper-center, replacing or beneath round counter during boss fights.
- **Format**: full-width bar with phase markers (33% / 66% boundaries for mini-boss, 66% / 33% / 15% for full boss).
- **Lifecycle**: appears on boss spawn, disappears on death.
- **Content**: boss name + current phase + HP bar.
- **Motion** (user, 2026-06-17): the depleting fill **slides** to the new value instead of
  snapping. Both the player HEALTH bar (top-left) and the boss bar use
  `acc_set_bar_smooth()` in `_acc_health_bars.gsc`, which animates the stock `createBar` fill
  with `scaleOverTime` (0.25 s glide) rather than the instant `hud::updateBar` width set. The
  round-progress / zombies-remaining bar (`CoD.AccRoundRing`, `acc_hud.lua`) slides the same
  way via the LUI `beginAnimation` tween. See docs/42.

#### 7. Damage numbers (crosshair-anchored)

- **Position**: a single number centered just above the crosshair (reads as damage on
  the zombie you're aiming at) — `CoD.AccDmgNum` in `acc_hud.lua`. Over-entity floating
  text was rejected (requires overriding `CoD.Waypoints`; see `_acc_dev.gsc` comment).
- **Batching**: sustained fire accumulates into one steadily-updating number over a
  ~0.1s window (no flicker storm); hides ~0.5s after the last hit.
- **Color**: amber `(1.0, 0.88, 0.25)` for normal hits, **teal `(0.20, 0.95, 0.85)`
  when the batch landed a headshot** (user, 2026-06-17). Headshot is sticky-OR'd across
  the batch — any head hit in the window tints the number teal.
- **Size**: text scale `1.52` (20% smaller than the original `1.9`, user 2026-06-17).
- **Encoding**: `accDmgNum` clientuimodel int = `min(dmg,65535)*4 + headshot_bit + parity`
  (18-bit field, fits exactly; parity flips so identical numbers re-pop).

#### 8. Emergency Drop prompt

- **Position**: contextual - shows when player is on an active power switch trigger.
- **Format**: `[Hold F] Emergency Drop - 3 Shards`.

### HUD elements we deliberately DON'T have

- **Minimap** - no. Zombies maps don't have them; would undercut zone-memorization skill.
- **Enemy HP bars on all zombies** - no (this is what Targeting Visor item unlocks).
- **Compass / waypoint arrows** - no.
- **Kill feed** - no. Stock zombies doesn't show them; we don't either.
- **Persistent combo counter** - no.

## HUD Priority / Stacking Rules

When multiple custom elements are visible simultaneously, draw order (bottom to top):

1. Stock base (round, crosshair, etc.)
2. Weapon status
3. Cyberware stack
4. Items row
5. Shards / Points row
6. Objective prompts (always on top unless boss active)
7. Boss health bar (takes priority over objectives during boss)
8. Interaction prompts (contextual; always top)

## LUI Widget Plan (Phase 4)

Each custom HUD element is planned as a distinct LUI widget. File layout:

```
ui/uieditor/widgets/zm_abandoned_cyber_city/
  acc_data_shards_hud.lua
  acc_cyberware_stack.lua
  acc_weapon_status.lua
  acc_boss_items_row.lua
  acc_objective_prompt.lua
  acc_boss_health.lua
  acc_emergency_drop_prompt.lua
```

Each widget:

- Pulls state via clientfields from GSC.
- Renders in the in-game HUD menu hierarchy.
- Animates on state change (fade, pulse).

See [01_toolchain.md](01_toolchain.md) and community LUI references before implementing.

## Accessibility Considerations

- **Colorblind mode**: Cyberware branch icons (Overclock / Subroutine / Reflex) use both color AND a distinct shape, so color-blind players can distinguish. Stock BO3 has a colorblind toggle that applies globally; we respect it where it makes sense.
- **Text size**: HUD text sizes respect stock scaling (a few community zombies maps break this; we won't).
- **Reduced-motion**: pulse/animation on state changes can be disabled via the modifier system (Phase 4 addition).
- **Screen-reader**: not supported. BO3 has no TTS.

## Accessibility - OUT OF SCOPE

- Full audio-visualization-for-deaf-players (would require ground ripple effects for footstep audio, etc.). Stock BO3 doesn't have it; we don't add it.
- One-handed control schemes.

## Implementation Status

- Phase 3: `iprintln` text for all custom state changes (Data Shards, Cyberware, tier-up, ability activation, boss item pickup). Ugly but functional for scripting playtest.
- Phase 4: full LUI widget set as outlined above.

## Tuning Levers

- **Element position**: all custom elements are positioned in a config block in the LUI widget init; playtest can rapidly shuffle layout.
- **HUD element visibility toggles**: a set of dvars (`acc_hud_shards`, `acc_hud_items`, etc.) lets players hide custom elements if they find the HUD busy.
