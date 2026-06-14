# 30 — Perk GDT + Radiant spec (the non-GSC remainder)

The perk-requirement fixes that are **GSC-reachable** were implemented 2026-06-14
(see [13_perks.md](13_perks.md) Implementation Status + CHANGELOG). This doc is
the **work order for the parts GSC physically cannot do** — baked weapon/asset
stats (GDT) and Radiant entities — to be applied with the **Asset Editor (APE)**
and **Radiant** on the Windows box, then a full rebuild.

**Why these can't be GSC:** the engine exposes no per-player/per-weapon setter
for fire rate, recoil, reload time, weapon-swap time, explosion radius, or ammo
*capacity* (the cap, as opposed to current reserve). Verified against the stock
mirror — zero matches for any such setter. These values live in the weapon GDT
and are baked into the fastfile at build time.

**Global side-effect caveat (applies to every GDT item below):** weapon GDTs are
**shared, not per-player**. Editing a weapon's GDT changes it for everyone holding
that weapon, regardless of perk. The perk "fantasy" is preserved only because the
GSC half proactively *fills/uses* the raised values for perk owners — but a true
perk-gated stat is not achievable via GDT alone (the lone exception is the
recoil **variant-swap** pattern below). Decide per item whether the global effect
is acceptable or the line should be cut.

---

## GDT items

### Mule Kick — "The Armory" capacity (GSC fill is live; raise the caps here)

The GSC `armory_apply()` already fills reserves/grenades to `weapon.maxAmmo` on
Mega-apply, perk re-buy, and every Max Ammo. It is **inert until these caps go up**
(with stock GDTs it just tops to the stock cap = no visible bonus).

| Asset (GDT) | Field | Change |
|---|---|---|
| `frag_grenade` (default lethal) | `maxAmmo` (reserve cap) | stock → **stock + 2** (e.g. 4 → 6) |
| `cymbal_monkey` (default tactical) | `maxAmmo` | stock → **stock + 2** |
| Every primary in the roster (`zm_levelcommon_weapons.csv`: `ar_accurate`, `shotgun_fullauto`, …) | `maxAmmo` (reserve cap) | stock → **ceil(stock × 1.30)** |

- APE → Weapon → open asset (clone into the usermap `source_data` to override the
  stock def) → edit the `maxAmmo` field → save → add to `.zone` only if it's a new
  custom variant → full rebuild.
- **Strong descope candidate:** the +30% gun-reserve is a per-weapon fan-out across
  the whole roster *and* global. Consider shipping Armory **grenades-only** (+2/+2,
  just the 2 grenade GDTs) and dropping the gun-reserve +30%. Design call.

### Widow's Wine — frag radius + 6 web grenades

| Asset (GDT) | Field | Change |
|---|---|---|
| `sticky_grenade_widows_wine` | `explosionRadius` + `explosionInnerRadius` | × **1.25** each (+25% radius) |
| `sticky_grenade_widows_wine` | `maxAmmo` (reserve cap) | → **6** (so GSC `SetWeaponAmmoStock(…,6)` isn't clamped) |

- The Spiderman web-grenade **OHK** and the GSC top-up-to-6 are already coded; this
  GDT raises the ceiling the GSC fills to. Ship both.
- **`+50%/+25% EMP` line is a spec blocker, not a build task.** Stock Widow's Wine
  has **no EMP component** (it registers only the web grenade + webbed-knife
  variants). There is no "Widow's Wine EMP" asset to edit and no hook tying an EMP
  effect to `specialty_widowswine`. **Recommend design strike or re-scope** this
  line (likely a conflation with the EMP *elite* enemy / tactical-slot text).

### Deadshot — "American Sniper" no recoil (variant-swap, heavier)

Recoil is a static weapon-asset property — there's no per-player recoil field. A
*true* perk-gated zero-recoil needs the **variant-swap** pattern:

1. APE → duplicate each affected weapon to `<weapon>_acc_norecoil`, zeroing
   `gunKickPitch/Yaw Min/Max`, `gunKickAccel/SpeedMax`, `viewKickPitch/Yaw Min/Max`,
   and tightening `hipSpread*`/`adsSpread*`.
2. Register the new names in the `.zone` weapon table + precache; full rebuild.
3. GSC (extend `_acc_mega_bottles` `specialty_deadshot` Mega apply / `on_perk_lost`):
   `GiveWeapon` the `_acc_norecoil` twin on American Sniper, restore the base twin on
   loss — carrying ammo/PaP/clip/Tier state across the swap.
- **Heavy:** one twin per weapon, and PaP'd weapons need upgraded twins too. This is
  the same override-swap framework `_acc_weapon_abilities.gsc` plans for Stabilizer
  (currently an unimplemented stub).
- **Recommended scope:** either ship a flat low-recoil pass on a few sniper/marksman
  guns (always-on for that gun, not perk-gated — matches the sniper fantasy), or
  defer to the Phase-4 override system. Don't advertise true per-perk zero-recoil
  until that lands.

### Double Tap 2.0 — fire rate (already out of scope)

- Base **+33% RoF** is **engine-granted for free** the moment a player owns
  `specialty_doubletap2` (the machine grants it normally) — no GDT edit needed.
- Mega Gun Slinger **+50% RoF** has **no GDT or GSC lever** (no per-perk fireTime
  field). The doc already re-scoped Double Tap to **damage-only** (+3% base / +6%
  Mega, both shipped in `_acc_damage.gsc`). **Action: none — just don't promise the
  +50% RoF number in the LUI card.** The Mega's mechanical benefit in-build is +6%
  damage.

### Speed Cola — reload/drink/swap (mostly un-gateable, design decision)

All three are GDT-baked **and** cannot be gated per-perk (no GSC weapon-timing
setter, no swap-on-perk hook), so any edit is **unconditional/map-wide**:

| Line | Asset / field | Note |
|---|---|---|
| Mega **+65% reload** | every weapon `reloadTime`/`reloadEmptyTime` ≈ × 0.91 over the engine +50% | unconditional; speeds up non-Speed-Cola players too |
| Base **~40% shorter drink** | `zombie_perk_bottle_*` drink anim ≈ 0.60× length | one map-wide value; base+Mega tiers not separable |
| Base **~30% faster swap** + Mega +15% switch | every weapon raise/drop anim ≈ 0.70× | unconditional, per-weapon |

- **Recommendation:** either **cut** the drink/swap/+65% lines from Speed Cola's value
  prop, or accept them as a **static map-wide QoL** and document as such. Base stock
  **+50% reload** already works for free via the specialty. Design call.

---

## Radiant items

### Per-round rotating Lab machines (rotation lockout)

The rotation **brain** is live (`_acc_map_randomizer::roll_perk_rotation` rolls
4-of-9 after decontamination into `level.acc_perk_rotation`), but
`apply_perk_rotation_to_machines` is a `TODO(acc-geom)` stub because **no
`acc_lab_perk_*` entities exist**. Today all 9 perks are always buyable from fixed
machines and the lockout never happens.

- In Radiant, place **4** perk-machine entities tagged `acc_lab_perk_a` / `_b` /
  `_c` / `_d` (the slot indices `apply_perk_rotation_to_machines` reads). Wire them
  so each can be reskinned/assigned to `level.acc_perk_rotation[slot]`.
- Then finish `apply_perk_rotation_to_machines` (assign `acc_current_specialty`,
  add a reader that makes a machine dispense/lock per the rolled specialty) — GSC,
  but blocked on the entities existing first.
- This is a **larger design+geometry task** (consolidating 9 fixed machines into 4
  rotating ones); see [13_perks.md](13_perks.md) "Per-Round Rotating Lab Machines".

---

## Build reminder

Per [CLAUDE.md](../CLAUDE.md): GDT/asset edits are **fastfile-baked** → need the
**full** `cod2map64` → LED → linker rebuild (not linker-only). Sync the repo into
the usermap (`tools/sync_to_modtools.ps1`) before building. The GSC halves shipped
2026-06-14 are linker-only and already in place.
