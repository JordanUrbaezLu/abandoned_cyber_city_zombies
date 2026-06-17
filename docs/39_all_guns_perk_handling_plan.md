# 39 — Plan: perk handling buffs on ALL guns (beat the twin cap)

**Status:** PLAN ONLY (not implemented). Authored 2026-06-16 after the live count-cap
re-test. Goal: get the Mega-perk *handling* buffs (recoil / fire-rate / reload / ammo) onto
as many box guns as possible — ideally all 14 — without the boot crash.

Damage is NOT in scope: `_acc_damage::acc_weapon_balance_mult` (`IsSubStr`) already applies
every gun's tier multiplier to its base + PaP + all twins at runtime. This plan is purely the
recoil/fire/reload/ammo *handling* layer that today only 5 guns get.

---

## LOCKED DECISIONS + research log (user, 2026-06-16)

**Accepted — build when ready:**

- **Lever 1 — Mega Mule Kick (Armory) reserve.** ⚠️ CORRECTION 2026-06-16: a *pure* runtime grant
  is IMPOSSIBLE. The reserve **cap (`maxammo`) is a baked GDT property and the engine clamps reserve
  to it**; there is no runtime `SetWeaponMaxAmmo`. `SetWeaponAmmoStock(gun, base×1.25)` clamps back to
  base = no boost. (Proven by our own code: `_acc_weapon_variants.gsc:516`, `_acc_mega_bottles.gsc:527`
  — the ammo twin exists *because* of this clamp.)
  - **Viable replacement (still removes the ammo twin axis):** bake `maxAmmo ×1.25` into the **base**
    gun GDTs (one number, zero twin slots), then RUNTIME-GATE THE FILL: clamp non-Armory players'
    reserve to the original base on weapon-give AND on Max-Ammo pickup; fill Armory players to the
    raised cap. The cap is baked (unavoidable); the *benefit* is runtime-gated (legal). Keeps Armory
    exclusive, frees the ammo axis → 10 guns fit at 140. Cost: a Max-Ammo powerup hook + a give hook.
  - **Alternatives:** keep ammo as a twin (→ only ~7 guns fit with the other axes), or redefine Armory
    to a runtime-legal effect (ammo regen / on-kill ammo / flat top-up). PENDING USER CHOICE.

- **Lever 2 — recoil → ONE Mega-only tier + Mega Deadshot retune.** Drop the recoil axis from 3
  levels to **2** = `{none, recoil50}`, where `recoil50` (twin recoil scale **×0.50** off the 2.1×
  base ≈ vanilla feel) is gated on **Mega Deadshot ONLY**. Base Deadshot gets **no recoil twin** —
  it's purely a damage perk now. And retune Mega Deadshot headshot **1.8 → 1.6**. Final:
  - **Base Deadshot:** 1.4× headshot, **no recoil change** (was -25% — removed; this is the dropped layer).
  - **Mega Deadshot (American Sniper):** **1.6×** headshot (was 1.8) + **-50% recoil** (was -40%).
  - **CASCADE TASKS (do together in the build):** `ACC_DEADSHOT_MEGA_MULT` 1.8→1.6 in
    `_acc_damage.gsc` (leave `ACC_DEADSHOT_MULT` = 1.4); recoil axis → single `recoil50` (`×0.50`)
    tier in `apply_recoil_overhaul.js` TWIN_DIMS + `_acc_weapon_variants.gsc` `variant_dims()`, and
    gate the recoil-twin swap on `has_mega_perk(specialty_deadshot)` (NOT base `HasPerk`); **update
    the Mega Deadshot UI card** (LUI / `_acc_perk_info`); **update all perk docs** (`13_perks.md`,
    `perk_abilities.md`, the mega-bottle doc) — base Deadshot loses its recoil line, Mega becomes
    1.6× HS + -50% recoil.

**Researched — Lever 3 (attachment recoil): NOT VIABLE → dropped.**
- The Skye box guns define **zero attachments** (ak47/asm1/galil/ppsh all 0) → nothing to apply;
  would need per-gun GDT/APE authoring (headless-blocked).
- Stock ZM `GiveWeapon` is single-arg; weapon+attachment combos are themselves weapon-table
  variants → consume the SAME cap, don't bypass it.
- → Recoil stays a baked twin (Lever 2 handles it).

**Deferred — Lever 4 (PaP `_up` removal): LAST RESORT** (only if we hit the cap again). Per-gun,
normal-PaP guns only; PDW / M1911 / Nail Gun keep their transform `_up` (akimbo/explosive PaP can't
be a damage-mult). Halves counts but needs a 2-path PaP rework — not needed while 1+2 fit.

**Budget with 1 + 2 (no 3, no 4):** 10 eligible guns × `[recoil(2)×fire(2)×reload(2) − 1 = 7] × 2
forms = 14/gun` = **140 twins**. Fits with margin (cap ≈230). The 4 structural guns
(Ripper/Nail/PDW/M1911) get runtime ammo + base perks + universal damage, no recoil/fire twins.

---

## 0. Hard facts (verified live — do NOT re-litigate)

- **Twin weapon-registration cap ≈ 230 (5 guns × 46).** Re-tested 2026-06-16 at **414 twins
  (9 guns) → game would not load** (silent access violation during weapon registration; the
  368-twin attempt crashed the same way). 230 boots, 368 & 414 crash. The linker happily packs
  any count — the cap is a **runtime** limit, so a clean `.ff` proves nothing; only a boot test does.
  `console_mp.log` shows **no fatal line** on the crash (it just stops mid weapon/asset load) —
  that silent stop *is* the signature of hitting the cap.
- **No per-player runtime setter exists for recoil / fire-rate / fire-time / spread / clip.**
  Grep-confirmed twice against the stock ref (`tmp/bo3_stock_ref`). The lone live weapon levers are
  **ammo** and **move-speed**. This is *why* the twin-swap system exists: to change recoil/fire you
  must swap to a pre-baked weapon variant. Keys/state tracking cannot apply these — they can only
  choose which baked variant to swap to. (So the "recoil boost at the player level" idea can't be
  done for recoil/fire — see §2.)
- **Ammo IS runtime-settable per-player/per-weapon:** `SetWeaponAmmoStock`, `GiveMaxAmmo`,
  `SetWeaponAmmoClip`, `SetWeaponAmmoOverall` all exist in stock. → the Armory axis can leave the
  twin system entirely (§1).
- **Base perk effects are already universal** (engine specialties, all 14 guns): Double Tap base
  +33% RoF, Speed Cola base +50% reload, Deadshot +1.8 headshot dmg + ADS auto-aim. Twins only add
  the **Mega EXTRAS** on top (Gun Slinger +40% RoF, Sleight +75% reload, Armory +25% ammo) plus the
  **recoil reduction** (the only effect with NO engine fallback).
- **The recoil axis is the budget killer.** Twin combos = recoil(3: none/-25/-40) × fastfire(2) ×
  fastreload(2) × ammo(2) − 1 = **23 combos/form × 2 forms = 46/gun**. The ×3 recoil factor is the
  biggest multiplier and the only one with no fallback.

### Per-gun structural eligibility (which guns CAN be twin guns)
Twin guns must be single-wield `bulletweapon`s with a clean `<base>_up` PaP name (the GSC builds the
PaP twin as `base_name + "_up" + suffix`).
- ✅ Clean: `s1_asm1`, `s1_ae4`, `t6_ak47`, `s1_tac19`, `t6_fiveseven` (current 5) +
  `s4_ppsh41_base`, `t6_galil`, `t6_olympia`, `t8_paladin_hb50` (tested-safe naming).
- ⚠️ `t5_ak74u` — PaP entry is `t5_ak74u_up_zm` (irregular `_zm`). GSC `base_name+"_up"` →
  `t5_ak74u_up_acc_*` but the GDT twin would be `t5_ak74u_up_zm_acc_*`. **Fix needed:** make the GSC
  PaP-twin resolver and `apply_recoil_overhaul` agree on the real `_up` asset name (pass `up` through,
  don't assume `base+"_up"`).
- ❌ `iw6_ripper` (convertible altWeapon), `t9_nail_gun` (projectile), `s1_pdw` / `s2_m1911`
  (akimbo `_rdw`/`_ldw`): separate boot-crash modes (altWeapon double-`_zm` Com_ERROR / projectile +
  akimbo break). These should **not** get recoil/fire twins. They still get: universal damage,
  runtime ammo (§1), and base engine perks — just not the baked recoil/fire layer.

### Budget math (twins per gun by axis set; cap ≈ 230)
| Axes baked as twins | combos/form | twins/gun | guns that fit |
|---|---|---|---|
| recoil×fire×reload×ammo (current) | 23 | 46 | 5 |
| recoil×fire×reload (ammo→runtime) | 11 | 22 | ~10 |
| recoil×fire (ammo→runtime, reload→base engine) | 5 | 10 | **all 14 (140)** |
| fire×reload (recoil→attachments, §2) | 3 | 6 | all 14 (84) |
| recoil only | 2 | 4 | all 14 (56) |

---

## 1. Phase 1 — move the AMMO axis to runtime (pure win, do this first)

The user's "player-key" idea, applied to the one axis where it actually works.

**Effect:** removes the `ammo` dimension from the twin matrix → every gun 46→22 (or 10 once
combined with §3). Frees ~120 slots immediately even on the current 5 guns.

**Implementation:**
1. `tools/apply_recoil_overhaul.js`: delete the `ammo` row from `TWIN_DIMS`.
2. `_acc_weapon_variants.gsc`: delete the `ammo` axis from `variant_dims()` + `level.acc_variant_axes`
   (and the `axis_ammo` function). Keep the matrix mirror in lock-step.
3. New runtime Armory grant in `_acc_weapon_variants.gsc` (or a small `_acc_armory.gsc`):
   - On `reconcile()` for the equipped primary: if `acc_mega_bottles::has_mega_perk(self,
     "specialty_<mulekick>")` (confirm the Armory specialty id), set the reserve to base × 1.25.
   - **Ammo model gotcha:** in the GDTs `maxAmmo` is a *magazine* count; in-game reserve rounds =
     `maxAmmo × clipSize`. `SetWeaponAmmoStock` takes **rounds**. So target stock =
     `round(base_maxAmmo × clipSize × 1.25)`. Don't clobber the player's *current* reserve downward —
     only raise the ceiling / top-up on acquire. Re-apply on weapon-change (Armory should feel like a
     bigger reserve cap, not a refill exploit).
   - Keys flush on death automatically — `reconcile()` re-derives from `HasPerk()` live, so no manual
     key store is needed (mirrors the existing recoil/fire handling).
4. `tools/reduce_base_ammo.js`: the variant GDT no longer has ammo twins — fine (it only touches
   clipSize/maxAmmo lines that still exist). No change required, but re-run it after regen.
5. Regenerate: `apply_recoil_overhaul.js` → `reduce_base_ammo.js` → `gdtdb /update` → build.
   Zone auto-rewrites to the smaller twin set.

**Verify:** boot, grab Mule Kick Mega, confirm reserve cap is ~25% higher on the held gun and
updates on weapon swap; confirm twin count dropped (zone `weaponfull` count).

---

## 2. Phase 2 — PROBE: runtime recoil via attachments (the big swing)

The only untested path to player-level recoil. If it works, recoil leaves the twin system and
**all 14 guns fit trivially**.

**Hypothesis:** `player GiveWeapon(weapon, attachments[])` is runtime, and a recoil-reducing
attachment (grip / stock / foregrip) is a **shared** asset that does NOT register a new per-combo
weapon (unlike twins). So Deadshot could re-give the held gun with a low-recoil attachment.

**Probe steps (cheap, do before committing to §3):**
1. Check which recoil-relevant attachments exist for the Skye imports (grep the gun GDTs / stock
   attachment tables for `grip`, `stock`, `foregrip`, `fmj`… and whether they carry `*Kick*`/recoil
   scales).
2. In a dev build, on a key press give the held gun with a recoil attachment
   (`self GiveWeapon(w, ["grip"])` style — confirm the BO3 API shape). Measure: does recoil drop?
   Does the weapon-asset count rise (i.e., does it count against the cap)? Does it survive
   weapon-change?
3. Gotchas to log: re-giving mid-fight resets ammo (handle like the current twin swap — carry ammo
   over); attachment may change the model/optics/handling; akimbo/projectile/convertible guns likely
   still can't take it.

**If YES:** move recoil to runtime attachments (per-player, key-driven) → drop the recoil axis from
twins → twins only need fire×reload (or fire alone) → all 14 single-wield guns + even the structural
ones (for recoil) covered. This is the ideal outcome.

**If NO:** fall back to §3.

---

## 3. Phase 3 — final twin layout (fallback if §2 fails)

With ammo already runtime (§1) and reload covered by base Speed Cola (engine, universal), bake
**recoil + fire** twins on all eligible guns:

- **recoil(3) × fire(2) = 5 combos/form = 10 twins/gun.**
- Eligible single-wield guns (after the AK-74u `_up_zm` fix): up to 10 guns → 100 twins (fits with
  room; could even keep reload as a 3rd axis on these = 22/gun × 9 ≈ 198, still under cap).
- Structural guns (Ripper / Nail Gun / PDW / M1911): **no recoil/fire twins** (crash modes). They
  keep universal damage + runtime ammo + base engine perks. Document this as intended.

**Coverage outcome (fallback):** ~10 guns get recoil + fire (+ maybe reload) twins; all 14 get ammo
(runtime) + base perks + damage. Only the 4 structural guns miss the baked recoil/fire layer.

---

## 4. Tool pipeline + backup discipline (the fragile part — get it right)

Canonical order, every time: **restore pristine → `apply_recoil_overhaul.js` → `reduce_base_ammo.js`
→ `gdtdb /update` → `build_map.ps1 -GscOnly`**.

Backup rules learned the hard way (source_data, install-side, gitignored):
- `apply_recoil_overhaul` keeps `*.acc-orig` (pristine Skye) per twin-gun; restores from it before
  scaling (idempotent). `reduce_base_ammo` keeps `*.acc-ammo-orig` and always reduces FROM it.
- **Adding a gun to the twin set:** first restore its base GDT to pristine and delete BOTH its
  `*.acc-orig` and `*.acc-ammo-orig` so each tool re-snapshots cleanly (else clips double-reduce and
  recoil gets wiped — `reduce` restores the whole file from its backup).
- **Whenever the twin matrix size changes:** delete `acc_weapon_variants.gdt.acc-ammo-orig` so
  `reduce` re-snapshots the new matrix (else it restores the old twin count).
- Existing twin guns: do NOT delete their `*.acc-ammo-orig` (holds post-recoil pristine-clip; deleting
  causes a double clip cut).

Known bug to fix while here: `reduce_base_ammo` `MAXAMMO_WEAPONS` protects only the exact
`t6_olympia` / `t6_olympia_up` names, so **Olympia *twins* get clipSize floored to 1** (double-barrel
→ single). Make the olympia clip-floor rule match by prefix so twins keep clip 2.

---

## 5. Verification & revert

- Build packs a `.ff` regardless of cap → **always boot-test** (`.\tools\run_game.ps1`). Loads = OK;
  black-screen/won't-load = cap or a structural crash. Check `console_mp.log` tail (silent stop mid
  weapon-reg = cap; explicit `Com_ERROR ..._zm_zm` = akimbo/altWeapon naming break).
- Keep each phase a separate build so a crash localizes the cause.
- **Revert any phase:** restore the touched base GDTs from `*.acc-orig`/`*.acc-ammo-orig`, revert the
  source edits (`apply_recoil_overhaul.js` GUNS/TWIN_DIMS + `_acc_weapon_variants.gsc`
  `variant_guns()`/`variant_dims()`), re-run the tool chain at the 5-gun / current-axis layout, gdtdb,
  build. Zone auto-regenerates.

## 6. Recommended execution order
1. **Phase 1** (ammo→runtime): independent, low-risk, real slot win. Ship + boot-test.
2. **Phase 2** (attachment-recoil probe): decides the ceiling. Cheap dev test, no commitment.
3. **Phase 3**: implement the final layout per the Phase 2 result. Boot-test after.
Each step is independently revertible; never expand the twin count without a boot test.
