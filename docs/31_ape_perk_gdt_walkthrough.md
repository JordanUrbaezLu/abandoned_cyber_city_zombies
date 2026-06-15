# 31 — APE weapon-GDT walkthrough (the perk magnitudes GSC can't deliver)

Click-by-click guide to apply the perk effects that are **baked weapon stats** and so
need the **Asset Property Editor (APE)** GUI — they have no GSC/runtime lever (each
"no lever" claim was grep-proven in the 2026-06-14 audit; see
[13_perks.md](13_perks.md) Implementation Status and [30_perk_gdt_radiant_spec.md](30_perk_gdt_radiant_spec.md)).

The **GSC halves are already shipped** (`_acc_mega_bottles.gsc` fills/uses the values;
`_acc_damage.gsc` applies the damage layers). This doc only raises the baked caps the
GSC fills to. **Everything here needs a FULL rebuild** (weapon GDTs are fastfile-baked):
`cod2map64` → LED → linker, or the Launcher with **Compile** + **Light** + **Link**.

> **Global caveat — these are NOT perk-gated.** A weapon's GDT is shared by everyone
> holding that weapon. The perk "fantasy" only holds because the GSC proactively fills
> the raised values for perk owners (grenade caps, Armory) or swaps a per-perk variant
> weapon in (recoil, fire rate). A flat reload/radius bump applies to **all** players.
> Decide per item (flagged below) whether the global effect is acceptable.

> **Reality check before you start.** The stock weapon **stat** files are baked into the
> base fastfiles and are *not* shipped as editable text in this public-tools install
> (`share/raw/gamedata/weapons/zm/` holds only `zm_levelcommon_weapons.csv`, the level
> table — no stat fields). APE's weapon editor reads the baked defs from the asset DB,
> so the workflow below depends on APE being able to **open the stock weapon**. If a gun
> doesn't appear in APE's weapon list, you'll need the weapon source extracted first
> (Launcher → extract, or a community weapon-source pack). Verify step 0 before investing.

---

## 0. Open APE and confirm you can edit a weapon (do this first)

1. Launch the **Mod Tools Launcher** → **Tools** → **Asset Editor** (APE), or run
   `<tools>\bin\APE.exe`.
2. Top-left asset-type dropdown → **Weapon**.
3. In the search box type `frag_grenade`. If it appears and opens with fields visible
   (Ammo, Reload, Idle, …) — APE can edit stock weapons here; continue. If the list is
   empty / the weapon won't open, stop and extract weapon source first (see reality
   check above) — the rest of this guide can't proceed without it.
4. **How saving works:** edits are written to a **GDT** under
   `<tools>\source_data\` (or your map's `source_data\`). To keep the override scoped to
   this map, **File → Save As** into `usermaps\zm_abandoned_cyber_city\source_data\acc_weapons.gdt`
   and add a zone line (step 6). Editing the stock GDT in place also works but is global
   to every map on the box.

---

> **VERIFIED 2026-06-14 — read before doing any cap row in §1-3.** Raising a carry **count**
> does NOT require editing a GDT: the GSC ammo builtins already in `_acc_mega_bottles.gsc`
> (`SetWeaponAmmoClip` / `GiveMaxAmmo`, the same ones stock `_loadout.gsc` uses) set the
> player's current count — **clamped to the weapon's baked cap.** So:
> - If your target is **≤ the stock cap**, it works in GSC with **zero APE/GDT work** (just
>   confirm in-game — e.g. if `SetWeaponAmmoClip(widows_wine, 6)` already yields 6, §3's cap
>   row is a no-op). This is the recommended path for all the cap items.
> - Only if your target **exceeds** the stock cap do you need a higher-cap GDT — and since
>   the **stock** grenade/gun GDTs aren't editable in this install (§4 SOURCING note), that
>   means a **HydraX-dumped clone** of the grenade with raised `maxAmmo`/`clipSize`, given to
>   players via `weaponfull,<clone>` in place of the stock one. Heavier; do it only if a
>   count genuinely above the stock cap is required.

## 1. Mule Kick "The Armory" — +2 lethal / +2 tactical  (GSC fill is live)

`_acc_mega_bottles.gsc::armory_apply` now fills the grenade **clip** to `weapon.maxAmmo`
(field bug fixed 2026-06-14 — was filling the unused reserve). It is inert until the cap
goes up.

| APE → Weapon | Field(s) to raise | From → To |
|---|---|---|
| `frag_grenade` (default lethal) | `maxAmmo` **and** `clipSize` | stock (e.g. 4) → **stock + 2** (6) |
| `cymbal_monkey` (default tactical) | `maxAmmo` **and** `clipSize` | stock → **stock + 2** |

- Raise **both** `maxAmmo` and `clipSize` to the same target. ZM carries grenades in the
  clip, but it's unconfirmed whether the engine clamps `SetWeaponAmmoClip` to `clipSize`
  or `maxAmmo` — setting both removes the ambiguity. The GSC fills to `maxAmmo`, so
  `maxAmmo` must be the target value.
- After save + rebuild: Mega Mule Kick, buy 1 frag/monkey, Max Ammo → you should top off
  to the new max. If you still cap at the old number, the other field was the clamp.

## 2. Mule Kick "The Armory" — +30% gun reserve  (GSC fill is live)

`armory_apply` already `GiveMaxAmmo`s every primary; raise each roster gun's reserve cap.

| APE → Weapon | Field | From → To |
|---|---|---|
| every primary in `zm_levelcommon_weapons.csv` (`ar_accurate`, `shotgun_fullauto`, `sniper_fastsemi`, …) | `maxAmmo` (reserve, not clip) | stock → **ceil(stock × 1.30)** |

- **Descope candidate:** this is a per-weapon fan-out across the whole roster *and*
  global (non-Mule players get it too). Consider shipping Armory **grenades-only**
  (section 1) and dropping the +30% gun reserve. Design call — flagged in
  [30_perk_gdt_radiant_spec.md](30_perk_gdt_radiant_spec.md).

## 3. Widow's Wine — +25% frag radius + hold 6 web grenades

| APE → Weapon | Field | Change |
|---|---|---|
| `sticky_grenade_widows_wine` | `explosionRadius` | × **1.25** |
| `sticky_grenade_widows_wine` | `explosionInnerRadius` | × **1.25** |
| `sticky_grenade_widows_wine` | `maxAmmo` **and** `clipSize` | → **6** |

- The +25% radius is **map-wide** for the web grenade (only Widow owners carry it, so the
  practical blast radius is effectively perk-scoped — acceptable).
- The 6-web cap: `_acc_mega_bottles.gsc` already sets the **clip** to 6 (Spiderman case).
  If the engine clamps the clip below 6 you'll see fewer — raise both fields to 6. If
  in-game you already get 6 with stock GDT, this row is a no-op (the clip wasn't clamped).
- **Frag-grenade (non-web) +25% radius:** the base Widow +25% applies to the *web*
  grenade, which is the Widow lethal — `sticky_grenade_widows_wine` above is the asset.
  (There is no separate "Widow frag" asset; the +50% frag **damage** is already GSC.)

## 4. Deadshot — recoil −35% (base) / −70% (Mega), off a 2.5× map baseline  (variant-swap)

> **PHASE 1 IMPLEMENTED + AUTOMATED (2026-06-14).** The model changed: every gun has a
> **2.5× recoil baseline** (map-wide skill rule) and Deadshot claws it back **−35% base /
> −70% Mega** (→ 1.625× / 0.75× vanilla). No manual APE needed — the GDTs are **plain text**
> and **`tools/apply_recoil_overhaul.js`** does it all: scales each gun's base + `_up` recoil
> ×2.5 *in place* (idempotent, keeps a `.acc-orig` backup) and generates the 12 twins
> (`<gun>[_up]_acc_recoil35` ×0.65, `_acc_recoil70` ×0.30) into
> `source_data/acc_weapon_variants.gdt`. Twins are wired in the zone + `build_available_twins()`.
> Remaining to test: a Launcher **Compile** (registers the GDT in `gdt.db`) + `acc_weapon_variants 1`.
>
> **PaP persistence (solved):** `acc_weapon_variants::true_base()` strips the `_acc_*` suffix
> before `get_base_weapon`, so the 5-tier PaP (and overclock state, headshot-exclusion) follow
> a gun across recoil swaps; and twins are **suppressed within 150u of the PaP machine** so the
> stock first-pack / tier-up operate on the real (upgrade-table-recognized) weapon.

The manual steps below are retained as reference (the script automates them); the SOURCING
note still governs *which* guns can be twinned (imported only).

> **SOURCING (verified 2026-06-14, live-machine + research pass — supersedes the step-0
> "reality check"):** the Mod Tools ship weapon **art** only (`wpn_t7_base`); the stock
> weapon **stat** GDTs (`frag_grenade`, `ar_accurate`, … as `bulletweapon`/`grenadeweapon`
> GDFs) are **not** present — on the live box, `source_data` has 173 GDTs and the only
> `bulletweapon`-typed ones are 102 community `skye_*` ports + a template `smg_standard.gdt`.
> **You therefore cannot duplicate a STOCK gun** (there is no GDT to clone) and a weapon GDT
> is necessarily *complete* (~800 fields; no partial "inherit-one-field" override). Two ways
> to get a cloneable base: **(A) build twins on an IMPORTED gun** (a Skye port — ships a full
> editable weaponfile GDT in `source_data`, no decompile; this is the practical path since
> the box arsenal imports them anyway), or **(B) decompile a stock gun with HydraX**
> (`Scobalula/HydraX`, reads the *running game* — NOT the Launcher, which has no extractor),
> then clone the dump under a new name (caveat: HydraX has a history of incomplete weapon
> dumps — validate one throwaway twin end-to-end before scaling).

> **Deadshot is a recoil REDUCTION, not zero** (docs/perk_abilities §7): **−25% on base
> Deadshot (any owner)** and **−50% on Mega "American Sniper."** So there are **two** recoil
> tiers → two twins per gun, and the base tier swaps in for *every* Deadshot owner (not just
> Mega). The framework derives the tier live and upgrades base→Mega automatically.

There is **no per-player recoil field** (grep-proven). Each tier is a cloned weapon you swap to:

1. In APE, open the base (imported) gun's GDT and **duplicate** its `bulletweapon` asset
   **twice** (the GDT is plain text — copy the `"<name>" ( "bulletweapon.gdf" ) { … }` block,
   change only the leading name):
   - `<weapon>_acc_recoil25` — **SCALE** the recoil fields to **×0.75** (−25%).
   - `<weapon>_acc_recoil50` — **SCALE** the recoil fields to **×0.50** (−50%).

   Scale (do **not** zero) these fields (names verbatim from a real weaponfile GDT — note the
   **`hip`/`ads` prefixes**; the bare `gunKick*` names were wrong):
   - `hipGunKickPitchMin/Max`, `hipGunKickYawMin/Max`, `hipGunKickAccel`, `hipGunKickSpeedMax`,
     `hipGunKickStaticDecay`, `hipGunKickSpeedDecay`
   - `hipViewKickPitchMin/Max`, `hipViewKickYawMin/Max`
   - the mirrored `adsGunKick*` / `adsViewKick*` set
   - **Keep `clipSize` / `maxAmmo` identical to the base** — the swap engine copies clip +
     reserve across 1:1 and assumes the caps match.
2. Add each twin to the zone: `weaponfull,<weapon>_acc_recoil25` / `_acc_recoil50` (step 7),
   **and** add the exact names to `build_available_twins()` in `_acc_weapon_variants.gsc` (the
   GetWeapon allow-list). Bake the `_up` PaP twins too (e.g. `s1_tac19_up_acc_recoil50`).
3. **GSC framework — DONE** (`_acc_weapon_variants.gsc`): the reconcile loop gives the
   `_acc_recoil25` twin while base Deadshot is held and `_acc_recoil50` while Mega is held,
   restoring the base on loss, carrying clip/reserve across. PaP is handled by keeping the
   `_up` stem in the twin name. Driven from `_acc_mega_bottles.gsc` (`on_perk_bought` for the
   base tier, `apply_mega_effects` / `on_perk_lost` for Mega). Flip on with
   `acc_weapon_variants 1` once the twins above exist.
- **Lighter alternative:** bake **only** the `_acc_recoil50` (Mega) twins and skip the base
  −25% (the framework no-ops base Deadshot's recoil when no `recoil25` twin exists). Halves the
  APE work; base Deadshot then keeps only its ×1.5 headshot + ADS-snap (still distinct from Mega).

## 5. Double Tap "Gun Slinger" — +50% fire rate + −75% swap  (variant-swap)

> **✅ BUILT + AUTOMATED (2026-06-14).** No manual APE — `tools/apply_recoil_overhaul.js`
> generates the `fastfire` twin per gun (base + `_up`): `fireTime`/`holdFireTime` ×0.667
> (+50% RoF) **and** raise/drop times ×0.25 (−75% swap, bundled — both gate on the DT Mega
> flag). Wired in the zone + `build_available_twins()` + `_acc_weapon_variants.gsc::axis_fire`.
> The +6% damage alternative below was **dropped** (Double Tap 1.0 is rate-only). Remaining:
> Launcher Compile + in-game feel confirm. The text below is kept as background.

Same pattern as #4 (same imported-base sourcing constraint) — there is **no fire-rate setter
or dvar anywhere** (grep-proven; stock DT2's +33% is hardcoded to the specialty). Clone each
gun to `<weapon>_acc_fastfire` and **lower** `fireTime` (lower = faster; ×0.667 ≈ +50% RoF),
plus `holdFireTime` / `introFireTime` as needed; register the twins (zone line **+**
`build_available_twins()` entry); the swap engine `GiveWeapon`s the fast twin while Gun
Slinger is held. (Do **not** rely on `fireTimeAkimbo` — that key was NOT confirmed in a real
BO3 weaponfile; akimbo is a separate dual-wield variant, not a field.)

- **Heavy** (twin per weapon + PaP twins) — shares the #4 framework, which is **already
  built** (`_acc_weapon_variants.gsc`, token `fastfire`). Build both swaps at once if you
  build either; a combined `<weapon>_acc_norecoil_fastfire` clone is auto-preferred if baked.
- **Cheaper alternative (recommended):** keep Gun Slinger as its **+6% damage** half
  (already shipped) plus a flat low-`fireTime` pass on a couple of signature guns
  (always-on). The +50% RoF card line stays only if you commit to the twin framework.

## 6. Speed Cola — Mega +70% reload (variant-swap); drink/swap resolved

> **✅ RESOLVED (2026-06-14)** — the "all map-wide / cut-or-accept" framing is superseded:
> - **Mega +70% reload — BUILT, perk-gated** via the `fastreload` twin (`reloadTime` /
>   `reloadEmptyTime` / `*AddTime` ×0.882 on top of the engine +50% → ~+70% net), generated
>   by `tools/apply_recoil_overhaul.js`, wired in the zone + `build_available_twins()` +
>   `_acc_weapon_variants.gsc::axis_reload`. **Not** map-wide. (+65% → **+70%**.)
> - **Faster perk-drink — CUT** (shared map-wide anim, played before you own the perk; no
>   per-perk lever). Removed from the card (docs/perk_abilities §3).
> - **Faster weapon-swap — moved to Double Tap's Gun Slinger** (the `fastfire` twin, §5);
>   not a Speed Cola effect.
>
> Base **+50% reload** + barrier repair stay free from the stock specialty. Remaining:
> Launcher Compile + in-game reload-feel confirm (tune the generator's `RELOAD` constant).

---

## 7. Add zone lines + rebuild (after any of the above)

1. For any **new custom variant** weapon (the `_acc_norecoil` / `_acc_fastfire` twins),
   add to `zone_source\zm_abandoned_cyber_city.zone`:
   ```
   weaponfull,<weapon>_acc_norecoil
   weaponfull,<weapon>_acc_fastfire
   ```
   Edits to an **existing** stock weapon's fields (sections 1–3, 6) need **no** zone line —
   the weapon is already pulled in via the `zm_levelcommon_weapons.csv` stringtable.
2. **Sync** the repo into the usermap: `.\tools\sync_to_modtools.ps1`.
3. **Full rebuild** (weapon GDTs are BSP-independent but fastfile-baked, so a linker-only
   pass is enough *if no geometry changed* — but GDT asset changes are safest with a full
   Launcher build): Launcher → select map → **Compile + Light + Link** → Build. Or
   linker-only: `<tools>\bin\linker_modtools.exe -language english -modsource zm_abandoned_cyber_city`.
4. **Verify in-game** (per [23_launch_runbook.md](23_launch_runbook.md)): launch with
   `acc_test_boss 1` to farm Mega Bottles fast, Mega the perk, and confirm the magnitude
   (grenade count, blast size, recoil, RoF). The build log + `console_mp.log` will flag a
   `missing material/xmodel` if a clone references an unbuilt asset.

## Priority order (smallest payoff-to-effort first)

1. **Widow 6-web cap + frag radius** (section 3) — 1 asset, 3 fields, GSC already fills.
2. **Armory grenade caps** (section 1) — 2 assets, GSC already fills.
3. **Armory +30% gun reserve** (section 2) — roster fan-out; descope candidate.
4. **Speed Cola timings** (section 6) — easy fields but map-wide; decide cut vs ship.
5. **Deadshot no-recoil + Gun Slinger fire rate** (sections 4–5) — heavy variant-swap
   framework; build together or use the lighter always-on alternatives.
