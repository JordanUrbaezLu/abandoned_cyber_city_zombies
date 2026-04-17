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
| **Perk Ability** (Aura Blast) | **G** (KBM) / **D-pad Up** (Gamepad) | Separate from weapon ability so players can chain weapon-ability → aura blast → weapon-ability without conflict. Listens for `"acc_perk_ability"` notify. Bind via console: `bind g notify acc_perk_ability`. See [13_perks.md — Perk reference, §9 Aura Blast](13_perks.md#perk-reference-base--mega). |
| Cyberware Kiosk interaction | Hold F on the kiosk (Spawn Plaza) | Stock interact, Cyberware handled contextually |
| Overclock Terminal interaction | Hold F on the terminal (Lab) | Stock interact |
| Pack-a-Punch interaction | Hold F on the PaP machine (Lab) | Stock interact, our code multiplies to L1-L5 |
| Hack Terminal activation | Hold F on terminal (Corp Plaza) | 500-Point cost |
| Vault Overload activation | Hold F on terminal (Server Vault) | 1000-Point cost |
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

- **Round counter** - upper-right corner.
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

#### 7. Damage numbers (optional, modifier-gated)

- **Off by default** (feels arcade-y; most zombies players dislike them).
- **Enable via modifier**: `acc_mod_damage_numbers` dvar or a modifier toggle.
- **Format**: floating text that rises from the hit location and fades.
- **Color**: white for body, yellow for headshot, red for boss hits.

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
