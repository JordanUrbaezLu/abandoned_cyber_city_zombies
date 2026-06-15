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

The GSC `armory_apply()` fills gun reserves (`GiveMaxAmmo`) and the **grenade clip**
(`SetWeaponAmmoClip`, fixed 2026-06-14 — was wrongly writing the unused grenade
reserve) to `weapon.maxAmmo` on Mega-apply, perk re-buy, and every Max Ammo. It is
**inert until these caps go up** (with stock GDTs it just tops to the stock cap = no
visible bonus). Note grenades are clamped to their GDT **carry cap**, not a reserve.

| Asset (GDT) | Field | Change |
|---|---|---|
| `frag_grenade` (default lethal) | `maxAmmo` (grenade carry cap) | stock → **stock + 2** (e.g. 4 → 6) |
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
| `sticky_grenade_widows_wine` | `maxAmmo` (grenade carry cap) | → **6** (so the GSC `SetWeaponAmmoClip(…,6)` fill isn't clamped below 6) |

- The Spiderman web-grenade **OHK** and the GSC top-up-to-6 are already coded; the GSC
  now writes the **lethal clip** (`SetWeaponAmmoClip`, fixed 2026-06-14 — the web
  grenade is the player's lethal, carried in the clip per `_zm_perk_widows_wine.gsc:214`),
  so this GDT only matters **if** the engine clamps the clip to the carry cap below 6.
  Confirm in-game: if `SetWeaponAmmoClip(web, 6)` already yields 6, this row is moot.
- **`+50%/+25% EMP` line is a spec blocker, not a build task.** Stock Widow's Wine
  has **no EMP component** (it registers only the web grenade + webbed-knife
  variants). There is no "Widow's Wine EMP" asset to edit and no hook tying an EMP
  effect to `specialty_widowswine`. **Recommend design strike or re-scope** this
  line (likely a conflation with the EMP *elite* enemy / tactical-slot text).

### Deadshot — recoil −35% (base) / −70% (Mega), off a 2.5× map baseline (variant-swap)

> **PHASE 1 IMPLEMENTED + AUTOMATED (2026-06-14).** Model: every gun's base recoil is **×2.5**
> (map-wide skill rule, edited in place in the Skye GDTs) and Deadshot reduces it **−35% base
> / −70% Mega** off that baseline (→ 1.625× / 0.75× vanilla). `tools/apply_recoil_overhaul.js`
> does the base scaling + generates the 12 twins; `_acc_weapon_variants.gsc` swaps them per
> perk (base Deadshot + Mega both poke it via `_acc_mega_bottles`). **PaP persists** across the
> swaps via `acc_weapon_variants::true_base()` + a 150u machine-proximity twin suppression.
> See [31_ape_perk_gdt_walkthrough.md](31_ape_perk_gdt_walkthrough.md) §4 for the full recipe.

Recoil is a static weapon-asset property — there's no per-player recoil field. Deadshot is a
recoil **reduction** off the 2.5× baseline (docs/perk_abilities §7): **−35% any owner, −70%
Mega.** So it's **two twins per gun** via the **variant-swap** pattern:

1. APE → duplicate each affected (IMPORTED) gun to **two** twins and **SCALE** the recoil
   fields (do NOT zero): `<weapon>_acc_recoil25` = ×0.75, `<weapon>_acc_recoil50` = ×0.50.
   Fields: `hipGunKickPitch/Yaw Min/Max`, `hipGunKickAccel/SpeedMax/StaticDecay/SpeedDecay`,
   the `adsGunKick*` mirror, `hipViewKickPitch/Yaw Min/Max` + `adsViewKick*`. (Field names
   corrected 2026-06-14 — bare `gunKick*` was wrong; recoil keys carry `hip`/`ads` prefixes.
   **Base must be an IMPORTED gun or a HydraX dump — stock guns have no editable GDT to
   clone**, see docs/31 §4 SOURCING + docs/22 "Weapon-GDT sourcing reality".)
2. Register the twin names in the `.zone` (`weaponfull,<name>`) + `build_available_twins()`;
   rebuild. Bake the `_up` PaP twins too.
3. GSC — **DONE** (`_acc_weapon_variants.gsc`): the reconcile loop `GiveWeapon`s the
   `_acc_recoil25` twin while base Deadshot is held and `_acc_recoil50` while Mega is held,
   restoring the base on loss, carrying clip/reserve across (PaP handled by keeping the `_up`
   stem). It's the same override-swap framework `_acc_weapon_abilities.gsc` Stabilizer now
   drives (`apply_timed_variant`).
- **Lighter scope:** bake only the `_acc_recoil50` (Mega) twins — base Deadshot then keeps
  just its +1.4 headshot bonus + ADS-snap (the framework no-ops the −25% with no `recoil25` twin).

### Double Tap 1.0 — Gun Slinger +50% fire rate + −75% swap (weapon-variant swap)

> **✅ BUILT + AUTOMATED (2026-06-14).** Done via the `fastfire` weapon-variant twin —
> `fireTime ×0.667` (+50% RoF) **and** raise/drop times `×0.25` (−75% swap), bundled since
> both gate on the Double-Tap Mega flag. Generated headlessly by
> `tools/apply_recoil_overhaul.js` into `source_data/acc_weapon_variants.gdt`, wired in the
> zone (`weaponfull,*_acc_fastfire*`) + `build_available_twins()` +
> `_acc_weapon_variants.gsc::axis_fire`. The "+6% damage" alternative below was **dropped**
> (Double Tap 1.0 is rate-only). Remaining: a Launcher Compile + in-game feel confirm (tune
> the `FIRE`/`SWAP` constants in the generator). The bullets below are kept as background.

- Base **+33% RoF** is **engine-granted for free** the moment a player owns
  `specialty_doubletap2` — no GDT edit needed. **Verified 2026-06-14:**
  `_zm_perk_doubletap2.gsc` has *zero* fire-rate code (only registration), so the
  +33% is hardcoded to the specialty in the engine.
- Mega Gun Slinger **+50% RoF** has **no runtime lever** — grep over the entire stock
  script tree returns **no** `Set*FireRate`/`ScaleWeaponFire*` builtin and **no**
  fire-rate dvar. So the only way to make a gun fire faster is the **`fireTime`
  weapon-variant swap** — exactly the same framework as Deadshot no-recoil below: clone
  each gun to `<weapon>_acc_fastfire` with a lower `fireTime` (and `fireTimeAkimbo`),
  register the twins, and `GiveWeapon` the fast twin while Gun Slinger is held (carrying
  ammo/PaP/clip across), restoring the base twin on loss. **Heavy:** one twin per
  weapon, PaP'd twins too. See the variant-swap how-to under Deadshot, and the
  step-by-step in [31_ape_perk_gdt_walkthrough.md](31_ape_perk_gdt_walkthrough.md).
- **Cheaper alternative (recommended if the variant framework isn't built):** keep
  Gun Slinger as the **+6% damage** half (already shipped in `_acc_damage.gsc`) and a
  flat low-`fireTime` pass on a couple of signature guns (always-on, not perk-gated),
  rather than a full per-weapon twin set. Design call.

### Speed Cola — Mega +70% reload (weapon-variant swap); drink/swap resolved

> **✅ RESOLVED (2026-06-14).** The old "all map-wide / un-gateable, cut-or-accept"
> framing is superseded:
> - **Mega +70% reload — BUILT, perk-gated.** Via the `fastreload` weapon-variant twin
>   (`reloadTime`/`reloadEmptyTime`/`*AddTime` ×0.882, layered on the engine's +50% →
>   ~+70% net), generated by `tools/apply_recoil_overhaul.js`, wired in the zone +
>   `build_available_twins()` + `_acc_weapon_variants.gsc::axis_reload`. **Not** map-wide —
>   only Speed-Cola-Mega owners swap to the twin. (Spec number corrected +65% → **+70%**.)
> - **Faster perk-drink — CUT.** Shared map-wide anim, played before you own the perk, so
>   no per-perk lever exists. Removed from Speed Cola's card (docs/perk_abilities §3).
> - **Faster weapon-swap — moved to Double Tap's Gun Slinger** (the `fastfire` twin's
>   raise/drop ×0.25); it is **not** a Speed Cola effect.
>
> Base **+50% reload** + faster barrier repair remain free from the stock specialty.
> Remaining: a Launcher Compile + in-game confirm of the reload feel (tune the `RELOAD`
> constant in the generator if the engine +50% composes differently than assumed).

---

## Radiant items

### Per-round rotating Lab machines (rotation lockout)

The rotation **brain** is live (`_acc_map_randomizer::roll_perk_rotation` rolls
4-of-9 after decontamination into `level.acc_perk_rotation`), but
`apply_perk_rotation_to_machines` is a `TODO(acc-geom)` stub because **no
`acc_lab_perk_*` entities exist**. Today all 9 perks are always buyable from fixed
machines and the lockout never happens.

> **Headless lockout option (no Radiant needed) — found by the 2026-06-14 audit.**
> Stock `vending_trigger_think` calls `level.custom_perk_validation` on the trigger
> before every purchase (`_zm_perks.gsc:560-562`); the trigger's perk is
> `self.script_noteworthy`. So the **4-of-9 lockout gate** can be enforced entirely in
> GSC on whatever machines exist:
> ```gsc
> // in _acc_map_randomizer init:
> level.custom_perk_validation = &acc_perk_buy_allowed;
> function acc_perk_buy_allowed( player )
> {
>     if ( !isdefined( level.acc_perk_rotation ) || level.acc_perk_rotation.size == 0 )
>         return true;                                   // pre-roll: allow all
>     return IsInArray( level.acc_perk_rotation, self.script_noteworthy );
> }
> ```
> Caveat: this only gates the **machines that exist** (currently 3 inline structs), and
> it cannot *re-skin* a live machine to a new perk (the stock trigger snapshots its perk
> once at spawn). The full designed experience — 4 dedicated Lab machines whose perk
> rotates each round — still needs the Radiant entities below. **Left off by default: a
> 4-of-9 lockout is a balance decision (locks 5/9 perks per round); enable on request.**

- In Radiant, place **4** perk-machine entities tagged `acc_lab_perk_a` / `_b` /
  `_c` / `_d` (the slot indices `apply_perk_rotation_to_machines` reads). Wire them
  so each can be reskinned/assigned to `level.acc_perk_rotation[slot]`.
- Then finish `apply_perk_rotation_to_machines` (assign `acc_current_specialty`,
  add a reader that makes a machine dispense/lock per the rolled specialty) — GSC,
  but blocked on the entities existing first.
- This is a **larger design+geometry task** (consolidating 9 fixed machines into 4
  rotating ones); see [13_perks.md](13_perks.md) "Per-Round Rotating Lab Machines".

---

## Adding a weapon-variant effect (the extensible framework — for agents)

`_acc_weapon_variants.gsc` is a **data-driven, effect-agnostic** swap engine. The swap
mechanics (instant `SwitchToWeaponImmediate`, re-entrancy mute, `true_base()` PaP keying,
`_up`-twin upgrade registration, near-PaP suppression, laststand defer) are **shared and
never need to change**. A new perk/ability effect is added by declaring an **axis** and
baking its **twins**. Each axis is one independent weapon-stat dimension (recoil, fire rate,
reload, …); the gun a player holds is `<gun>[_up]_acc_<tok1>_<tok2>…` for the active tokens,
resolved with graceful fallback (a missing combined twin degrades to a partial effect, then
base). Existing axes: **recoil** (Deadshot −35%/−70%), **fire** (Gun Slinger), **reload**
(Speed Cola Mega).

**To add an effect (e.g. a new ability that lowers ADS-in time), do ONLY these — no core change:**

1. **Bake the twins.** Add a dimension to `tools/apply_recoil_overhaul.js` `TWIN_DIMS` (a
   `[suffix, {field: scale}]`) — the generator already scales recoil/fire/reload/swap GDT
   key-sets; add a new key-set in `tools/gen_weapon_variant_gdt.js` if your field isn't covered.
   Run it → twins named `<gun>[_up]_acc_<token>` land in `source_data/acc_weapon_variants.gdt`.
2. **Zone:** add a `weaponfull,<twin>` line per new twin.
3. **`_acc_weapon_variants.gsc`:**
   - `variant_dims()` — append your axis's token(s) (canonical order = generator order).
   - `build_available_twins()` — add the new combo suffix tails to `built` (the "compiled-in" gate).
   - Write an `axis_<name>()` returning your token when the perk/ability is active (read
     `HasPerk`/`has_mega`; honor `timed_has()` for ability overlays).
   - `init()` — append `&axis_<name>` to `level.acc_variant_axes` (canonical order).
4. **Build** (full `cod2map64`→LED→linker — GDT is fastfile-baked). `true_base`/PaP/HUD all
   keep working because they're effect-agnostic.

`build_variant_suffixes()` (the stem-stripper list) is computed from `variant_dims()` as a
mixed-radix cross-product, so it stays in sync automatically. Keep `variant_dims()` order ==
`level.acc_variant_axes` order == the generator's `TWIN_DIMS` order.

## Build reminder

Per [CLAUDE.md](../CLAUDE.md): GDT/asset edits are **fastfile-baked** → need the
**full** `cod2map64` → LED → linker rebuild (not linker-only). Sync the repo into
the usermap (`tools/sync_to_modtools.ps1`) before building. The GSC halves shipped
2026-06-14 are linker-only and already in place.
