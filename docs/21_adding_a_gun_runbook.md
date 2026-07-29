# 21 — Adding a box gun (reusable runbook)

The repeatable recipe for adding a Skye-ported weapon to the map as a box gun
with **all twins, sounds, classification, and balance**. Companion to docs/21
(the original box-weapon import staging). **Sourcing + the perk-magnitude / twin-GDT
reference are folded in here** (formerly the standalone docs/21, 30, 31, 39).

> **Golden rule:** a gun already in the map is the template. Pick the closest one,
> trace how it is wired through the 10 points below, and mirror it. The Five-Seven
> (`t6_fiveseven`, pistol) and the AK-47 (now the Cold War `t9_ak47` AR — the original
> worked example used the BO2 `t6_ak47`, later swapped to the CW port) are both
> full-auto conventional imports, so their wiring mirrors almost every other box gun.

**Weapons are BOX-FED** — the mystery box charges a fixed price and the box pool is
flipped at runtime in GSC. **Five** player-requested wall-buys are kept live, though —
Five-Seven (Lab), Olympia (Bus Station), frag grenade (Spawn), the AK-47 (`t9_ak47`,
Abyss Layer 4) and the M60 (`t9_m60`, Abyss Layer 5); `remove_all_wallbuys()`
whitelists exactly those and strips every other stock wallbuy stub. The arsenal is
large (Apex pack + Skye ports + elemental bows + wonder specials), not a fixed
shortlist.

---

## 0. Prerequisites — sourcing & "is the asset installed?"

### Where the guns come from (verified 2026-06-12)

- **Assets = TheSkyeLord's weapon ports** ("Skye ports"): APE-ready per-game kits
  (`skye_*` GDTs + `model_export\skye_ports` + `xanim_export\skye_ports` + sounds +
  `share\raw\fx\skye_efx` + wallbuy chalk prefabs). GitHub hosts almost no actual BO3
  weapon *assets* — the ecosystem distributes them as kits via UGX-Mods / Modme
  threads (Mega/iCloud links); GitHub repos carry only the *wiring* (CSVs, zone lines,
  GSC). The multi-GB packs are a **user install step**, not something an agent
  downloads.
- **Wiring layer = `FanaticSoftware/Skye-Weapon-Templates`** — the same repo CLAUDE.md
  trusts as the "Pristine Launcher zm template". Each of its 15 per-game templates ships
  a pre-filled `gamedata/weapons/zm/zm_levelcommon_weapons.csv`, entry GSC/CSC, `.szc`,
  a `.zone` with the weapon + stringtable lines, and `share/raw` sound aliases
  (`skye_<game>_weapons.csv`). It is literally the template pack designed to pair with
  Skye's asset packs — use it as the reference for exactly which lines each gun needs.
- **Naming trap — the prefix names the source game/pack.** `t5_`=BO1, `t6_`=BO2,
  `t9_`=Cold War, `s1_`=AW, `iw4_`=MW2, `h1_`=MWR; `apex_*` = the Apex Legends pack;
  `s4_` = another pack (the PPSH port). These are CUSTOM weapons that ride in via the
  `zm_levelcommon_weapons.csv` stringtable, distinct from stock class names
  (`ar_accurate` etc.).
- **The `_zm` runtime-strip trap.** Some packs' GDT/zone asset ids carry a `_zm` **mode
  suffix that the engine STRIPS at runtime** (the whole Apex pack does this). So the
  script/CSV/box refs use the **bare** name (`apex_prowler`) while the **zone/GDT** keep
  `_zm` — follow the pack's ADD-TO files verbatim, and see the Ripper/akimbo gotchas
  below for the failure signatures when they disagree.
- **Practical limits & posture.** The Skye hub FAQ quotes a **~150-weapons-per-map**
  practical limit; our own empirically-measured runtime cap is different and governs —
  see **§A (twin weapon-count cap)**. Porting between CoD titles is community-tolerated
  at Workshop scale; the enforced norm is **credit the porter** — credit TheSkyeLord
  (weapons) + LilRobot (inspect script) + any pack author in `CREDITS.md` / the Workshop
  description before publishing Public.

### Is this gun installed on the box?

The gun's Skye GDT must already be in the Mod Tools install. Check **all three legs**
(GDT + model + sounds) — a GDT alone with no models/wavs is a dead port:

```powershell
$tools = "C:\Program Files (x86)\Steam\steamapps\common\Call of Duty Black Ops III 455130"
Get-ChildItem "$tools\source_data" -Filter "skye_*.gdt" | Select-Object Name
Get-ChildItem "$tools\model_export\skye_ports" -Directory | Select-Object Name
Get-ChildItem "$tools\sound_assets\skye_ports"  -Directory | Select-Object Name
```

- **GDT filename ≠ weapon (class) name.** `skye_t6_ak47.gdt` → asset `t6_ak47`;
  `skye_s1_tac-19.gdt` (hyphen!) → asset `s1_tac19` (no hyphen). The **weapon name**
  is the asset id inside the GDT, also the `model_export\skye_ports\<name>` folder.
- **The same gun can ship in multiple packs** (AK-47 exists as BO2 `t6_ak47`, AW
  `s1_ak47`, CW `t9_ak47`, … — all different guns). Confirm which one the user wants;
  the current roster uses the **Cold War `t9_ak47`**.
- If any leg is **missing**, stop — the user must install the pack first. (Trap seen
  2026-06-15: the BO1 Olympia/Galil GDTs were present but their models/sounds were not,
  so the fully-installed BO2 `t6_*` ports were used instead. Verify all three legs.)

### Can APE / the GDTs be edited at all?

The Skye GDTs are **plain text** in `source_data\`, so most edits are a text/regex pass
— no APE GUI needed. But if you do open **APE** (Mod Tools Launcher → Tools → Asset
Editor, or `<tools>\bin\APE.exe`): pick asset-type **Weapon**, search a name, confirm
it opens with fields visible. **SOURCING reality (verified 2026-06-14):** the Mod Tools
ship weapon **art** only (`wpn_t7_base`); the **stock** weapon *stat* GDTs
(`frag_grenade`, `ar_accurate`, … as `bulletweapon`/`grenadeweapon` GDFs) are **NOT**
present — a stock gun has no editable GDT to clone, and a weapon GDT is *complete*
(~800 fields, no partial "inherit-one-field" override). Two ways to get a cloneable
base: **(A) an IMPORTED gun** (a Skye port ships a full editable weaponfile GDT — the
practical path, since the box arsenal imports them anyway), or **(B) a HydraX dump** of
a stock gun (`Scobalula/HydraX`, reads the *running game*, not the Launcher — validate
one throwaway clone end-to-end first; HydraX has a history of incomplete weapon dumps).

Read the baked stats now — you need them for balance (step 7):

```powershell
$gdt = "$tools\source_data\skye_t6_ak47.gdt"
Select-String $gdt -Pattern '"(damage|minDamage|fireTime|fireType|clipSize|weaponClass)"\s+"[^"]*"' |
  ForEach-Object { $_.Line.Trim() } | Select-Object -Unique
```

`weaponClass` (rifle/smg/pistol/shotgun/sniper/spread/grenade/projectile) → the CSV
`class`/`weaponVO`, the ability/overclock family, and whether it takes the shotgun or
launcher special path.

---

## The 10 integration points

| # | File | What to add | Auto? |
|---|---|---|---|
| 1 | `gamedata/weapons/zm/zm_levelcommon_weapons.csv` | 1 gun row (`<name>,<name>_up,…`) | manual |
| 2 | `zone_source/zm_abandoned_cyber_city.zone` | `weapon,<name>` + `weapon,<name>_up` | manual |
| 3 | `sound/aliases/acc_skye_box_weapons.csv` | the gun's sound aliases | manual (script) |
| 4 | `_acc_map_randomizer.gsc` `register_mystery_box_pool` | add to `box_weapons` | manual |
| 5 | `_acc_weapon_abilities.gsc` | category + ability table + effect fn | manual |
| 6 | `_acc_overclocks.gsc` `weapon_name_to_family` | add to the family `*_list` | manual |
| 7 | `_acc_damage.gsc` `acc_weapon_balance_mult` | 1 balance line | manual |
| 8 | twin GDT (`source_data/acc_weapon_variants.gdt`) | hand-gen the gun's twins via `gen_weapon_variant_gdt.js` | manual+tool |
| 9 | `_acc_weapon_variants.gsc` `variant_guns()` (+ `form_bakes_suffix()` if gun-scoped) | add the base name | manual |
| 10| `zone_source/*.zone` twin block | the `weaponfull,<name>…` twin lines | manual |

Steps 8–10 are the **recoil/perk twins** — the thing a casual add forgets. They must
stay in sync: the twin GDT declares the variant weapons, `variant_guns()` allow-lists
them, the zone declares them. A mismatch = a missing-asset link error or a silent twin.
**Twin-less is a valid, shipped default** (see §A) — a new gun may skip 8–10 entirely.

---

## Step-by-step

### 1. Weapon table CSV — `gamedata/weapons/zm/zm_levelcommon_weapons.csv`
Mirror the closest gun's row. Columns: `weapon_name, upgrade_name, hint, cost,
weaponVO, …, in_box(=TRUE), …, class, …`. AR example:
```
t6_ak47,t6_ak47_up,,1250,rifle,,,,,TRUE,FALSE,FALSE,,,FALSE,TRUE,rifle,,,
```
`in_box` value is cosmetic (the box pool is flipped at runtime in GSC); the row's
real job is to load the weapon into `level.zombie_weapons`. `cost` is used by the 5 kept
wall-buys (Five-Seven, Olympia, frag, AK-47, M60) but moot for box-only guns (the box charges a
fixed price). (reconciled to code 2026-07-11) `weaponVO`/`class` = the `weaponClass`.

### 2. Zone weapon lines — `zone_source/zm_abandoned_cyber_city.zone`
In the box-guns block: `weapon,<name>` and `weapon,<name>_up`. (Dual-wield pistols
also get `_rdw_zm`/`_ldw_zm`/`_rdw_up_zm`/`_ldw_up_zm`; an AR does not.)
**TRAP:** the PaP form in the zone is `_up` (NOT `_up_zm`) for most Skye imports —
match the existing gun lines exactly. Pack-specific `_zm` asset ids (Apex, akimbo) are
the exception; follow the pack's ADD-TO files.

### 3. Sound aliases — `sound/aliases/acc_skye_box_weapons.csv`
Find the alias names the GDT expects and the wavs that exist:
```powershell
Select-String "$tools\source_data\skye_t6_ak47.gdt" -Pattern 'wpn_t6_ak47[a-z_]*' -AllMatches |
  ForEach-Object { $_.Matches.Value } | Sort-Object -Unique
Get-ChildItem "$tools\sound_assets\skye_ports\t6_ak47" -Recurse -Filter *.wav |
  ForEach-Object { $_.FullName.Substring($_.FullName.IndexOf("skye_ports")) }
```
Typical set: `_shot_plr`/`_shot_npc` + `_pap_shot_plr`/`_pap_shot_npc` (fire) and a
handful of foley (`_charge`/`_mag_in`/`_mag_out`/`_bolt_*`/`_futz`). `_plr` and `_npc`
both point at the same `_shot.wav`. **Don't hand-type the ~100-column rows** — clone
existing template rows and swap only Name (col 0) + FileSpec (col 3). The ASM1/TAC-19
fire rows + Five-Seven foley rows are the templates (see the worked example for the
exact PowerShell). The `.wav` files are already installed by the pack; you only add
aliases.

**USE THE GENERATOR — `tools/gen_box_weapon_sounds.js` (does fire + foley, 2026-06-15).**
Add the gun to its `GUNS[]` (`{ sid, shot:[…wavs], pap }`) and re-run. It clones the
templates and emits `wpn_<sid>_shot_plr/_npc` (one row per shot-variant wav → randomized)
+ `_pap_shot_*`, **and auto-scans `sound_assets\skye_ports\<sid>\foley\`** to emit one
alias per foley wav. Alias name = the GDT token the wav satisfies: the wav basename when
the GDT's xanim customnotes reference it exactly, or the digit-stripped stem for
round-robin variant wavs (since 2026-07-26 the generator parses `source_data\skye_*.gdt`
customnote tokens to pick the right one). Traps it encodes:
- **FIRE-ONLY = silent on RELOAD.** An older tool authored only fire rows, so some guns
  fired but had no bolt/mag/charge sound. Foley is not optional — the GDT references
  `wpn_<sid>_mag_in` etc. and a missing alias is just silence.
- **`<sid>` is the SOUND id, which DROPS underscores** for some guns:
  `t9_nail_gun`→`wpn_t9_nailgun`, `t8_paladin_hb50`→`wpn_t8_paladinhb50`. Find it from the
  GDT's actual `wpn_*` token prefix **and** the real `sound_assets\skye_ports\<folder>`
  name — not the weapon asset id. Wrong sid = every sound silent. (When the on-disk
  folder differs from the alias prefix, pass the `dir` field — e.g. Chicom's folder
  `t6_chicom_cqb` vs alias prefix.)
- **Cross-named foley** (AK-74u's `wpn_t5_tishina_bolt_back`): the auto-scan emits these
  correctly because it names by wav basename, not sid.
- **Camo/material `wpn_*` tokens are NOT sounds.** A sniper GDT has hundreds of
  `wpn_sniper_<gun>_*scope/camo/lens*` material tokens; only the `wpn_<sid>_*` ones with a
  matching wav are sounds. Driving foley from the wav folder (not the GDT token list)
  sidesteps this automatically.
- **Singular-token foley (variant wavs) — FIXED IN THE GENERATOR 2026-07-26.** A GDT
  customnote can play ONE unsuffixed token (`wpn_t9_streetsweeper_shell_in`) served by
  SEVERAL numbered wavs (`shell_in1..4.wav`) — the correct rows are N wavs under the SAME
  alias Name (engine round-robin, exactly like fire `shot1..6`). The old
  basename-as-alias scan emitted `shell_in1..4` alias NAMES instead, which the anim never
  plays → **the Streetsweeper + XM4 shipped 2026-07-10 with silent reloads** (China Lake
  had hit the same trap earlier). The generator now collapses `stem<digit>` wavs onto the
  GDT token when the token exists; sequentially-referenced names (`inspect_part1..4`,
  each played by its own note) still keep their basenames. Alias lookup is exact-name —
  a mismatch is pure silence, no error anywhere.
- **Projectile guns: grep `projExplosionSound`.** A launcher/GL's explosion sound is a
  separate alias — War Machine's `projExplosionSound` (`wpn_t6_grenade_explosion_npc`) had
  no alias anywhere → silent explosions until aliased to the Mahem explosion wav.
- **WATER-CONTEXT trap (a silent-fire cause, 2026-07-09): an alias row with
  `ContextType=water / ContextValue=under` and NO `over` sibling only plays UNDERWATER.**
  The G7's cloned `_fire_plr` rows were under-only → the shooter heard nothing while the
  3rd-person `_npc` rows (over) worked, so teammates could hear it. Every 1P fire alias
  needs a `water,over` row (blank context also works); shipped pattern is an over+under
  pair. **Silent-gun checklist: (1) wav cols 3/4/5 resolve, (2) `Secondary` col 9
  resolves (a dangling one DROPS the whole alias), (3) a `water,over` context row exists.**

**Build-time proof the aliases baked in:** the loaded sound bank
`usermaps\…\sound\zone\CachedBanks\all\zm_abandoned_cyber_city.all.sabl` GROWS. Errorlog
must show **0** sound/wav lines. A gun that's still silent in-game with aliases present →
check `console_mp.log` line `SOUND … .all.sabl <N>` loaded OK and that the `<sid>`
matches the GDT token exactly.

### 4. Box pool — `_acc_map_randomizer.gsc::register_mystery_box_pool`
Add the name to the `box_weapons` array. The clear/re-flag loop + the
`CustomRandomWeaponWeights` filter are generic — no other change.

### 5. Ability — `_acc_weapon_abilities.gsc`
Each weapon **category** has one live signature ability. To add a category:
- `weapon_name_to_ability_category()` — add a `<class>_list = array("<name>")` and an
  `if (array::contains(...)) return "<category>";`.
- `build_ability_table()` — `t["<category>"] = ability("<id>", <cd_sec>, &<effect>);`.
- The **effect fn** must be LIVE (self-contained or using a `_acc_damage` contract).
  Reusable contracts: `self.acc_ability_crit_shots` (N auto-crit shots at 4×) and
  `self.acc_ability_slug_next` (next shot 3×). Don't map to a stub. Cheapest live new
  ability = arm `acc_ability_crit_shots` to a count that fits the gun (the AR's **Focus
  Fire** = 6, vs the pistol's Precision Mode = 3). **Explosive specials** (Mahem, War
  Machine) take **no ability** — they mirror the launcher special path instead. (The China
  Lake was a third such special until it was removed in the 2026-07-06 Apex migration.)

### 6. Overclock family — `_acc_overclocks.gsc::weapon_name_to_family`
Add the base name to the matching `*_list` (`ar_list`/`smg_list`/`sg_list`/…). The
family **pools** (`build_family_pools`) exist only for ar/smg/shotgun/sniper/lmg (no
`special`/`pistol` pool), and are dead/unreferenced anyway — no pool edit needed.

### 7. Balance — `_acc_damage.gsc::acc_weapon_balance_mult`
One substring line: `if (IsSubStr(weapon_name, "<name>")) return <mult>;`. This is a
flat per-gun damage scale covering base + `_up` + every `_acc_*` twin in one match.
**Method:** the map is HARD + reward-progress, so equalize *effective* output across
the box. Compute raw DPS = `damage / fireTime` and pick a multiplier that lands the gun
in the intended tier relative to the others. The **live** anchors + the box-tier scoring
that drives pricing/rarity live in `_acc_damage::acc_weapon_balance_mult` and the tools
`tools/gen_box_dynamic.js` / `tools/compute_gun_tiers.js` — read those, don't trust a
memorized table (the original 2026-06-14 snapshot — Five-Seven ×0.375, Tac-19 ×0.75,
AK ×0.23; ASM1 has since been RETIRED — is historical). Headshot exclusion
(`is_weapon_headshot_excluded`) is **shotgun-only** — ARs/SMGs/pistols get the ~3×
headshot chain, so leave them out of it.

**TRAP — check the GDT's hit-location mults (`loc*`), not just `damage`.** The engine
multiplies `damage` by the hit-location field (`locTorsoMid`, `locHead`, …) **before**
`on_ai_damage` sees it, so the *real* body damage = `damage × locTorso` and the real
headshot = `damage × locHead × our 2.0`. Normal Skye rips ship `locTorso`=1.0 / limbs=1.0
(verified AK-47, ASM1), so `damage/fireTime` is the true body metric. **But MP-tuned rips
(esp. snipers) inflate ALL loc mults** — the Paladin shipped `locTorso` 5.0 (PaP 9.0),
limbs 4.0, `locHead` 7.5/10.0, so it one-shot *bodies and feet* at a mult that should
have capped it; the CEL-3 shipped `locTorsoUpper` 1.25→2.25 / `locNeck` 2.125→3.125.
Fix = **normalize the GDT's `loc*` mults to 1.0 install-side** (regex-replace the loc
fields, `gdtdb /update`, keep a `.acc-loc-orig` backup — helpers: `tools/fix_paladin_loc.js`,
`tools/normalize_sniper_loc.js`, `tools/normalize_mors_loc.js`). Then the additive model
holds (body=base, headshot=2×) and the balance mult means what the DPS math says.
**Always grep a new gun's `loc*` block; if `locTorso`≠1.0 it's an MP rip and the body
shot is secretly N× stronger than `damage` implies.**

### 8–10. Perk twins (recoil / Speed Cola / gun-scoped implants)

> **THE AXES (source of truth: `_acc_weapon_variants.gsc` `variant_dims()` +
> `level.acc_variant_axes` + `form_bakes_suffix()`).** There are **5** axes
> (`recoil`, `reload`, `turbo`, `lev_speed`, `brz`):
> - **GLOBAL (every conventional gun): `recoil50`** (Deadshot Mega, recoil ×0.50 off the
>   1.75× map base) × **`fastreload`** (Speed Cola Mega, `reloadTime` ×0.857 → ~+70% net).
>   3 combos × 2 forms (base/`_up`) = **6 twins/gun**. A new conventional gun gets these 6.
> - **GUN-SCOPED `turbo`** (Turbocharger boss-item implant → `sprintOutTime 0.2`), baked
>   for **`apex_beam_rifle` (the Havoc) ONLY** — 8 forms.
> - **GUN-SCOPED `spd1/spd2/spd3`** (Leviathan Axe +10%-swing-per-PaP-tier), baked for
>   **`leviathan` ONLY** — 3 tier forms (`base+spd1`, `_up+spd2`, `_up+spd3`); melee, so it
>   bakes NO recoil/reload forms.
> - **GUN-SCOPED `brz`** (Berzerker implant, boss item 11 → +35% axe swing), baked for
>   **`leviathan` ONLY** — one `_brz` form per `spd` tier, stacking with the spd tiers; the
>   trailing token so every non-Leviathan gun degrades cleanly to its other twins.
> - **Fastreload-ONLY wonder/special tier:** Mahem / Thundergun / Fire Bow / War Machine
>   bake *just* `_acc_fastreload` (Speed Cola Mega works on them; Deadshot deliberately
>   does not — recoil is meaningless on a launcher/wind-cone/bow). Fire Bow has no `_up`
>   (it PaPs in place) so only its base form bakes.
>
> **Current matrix ≈150 twins (2026-07-09):** 22 conventional guns × 6 = 132 + 8 Havoc
> turbo + the wonder fastreload forms + 3 Leviathan spd forms — ~80 under the ~230 boot
> cap (§A). **Don't trust a memorized total — recount from `variant_guns()` ×
> `variant_dims()` gated by `form_bakes_suffix()`.** Retired axes: `fastfire`/"Gun
> Slinger" (removed 2026-07-04 → now a runtime damage buff in `_acc_damage`, extra-bullet
> temper ×0.6→×0.8) and `ammo`/Armory (removed 2026-06-16 → runtime round-start refill,
> `_acc_mega_bottles::armory_refill`).

**How twins are generated TODAY — hand-generate, do NOT re-run the whole tool.**
`tools/apply_recoil_overhaul.js` is the *original* idempotent generator (it scales each
of its `GUNS[]` base GDTs ×1.75 in place with a `.acc-orig` backup, emits their
`recoil50`/`fastreload` twins, rewrites the zone twin block, and runs `gdtdb /update`).
**But the live roster now contains many twins its `GUNS[]` does NOT list** —
Blast-O-Matic, all Apex guns, XM4, Streetsweeper, Grav, the wonder tier, Leviathan, War
Machine — because those were **hand-generated** via scratchpad scripts that call
`tools/gen_weapon_variant_gdt.js`. **A full `apply_recoil_overhaul.js` re-run would DROP
every hand-built twin** (it rewrites `acc_weapon_variants.gdt` from its `GUNS[]` only).
So for a NEW gun:

1. **Bake the twins by hand.** Write/extend a scratchpad script that feeds
   `tools/gen_weapon_variant_gdt.js` (which scales the recoil/reload GDT key-sets and
   clones the `<gun>[_up]_acc_<combo>` blocks) — mirror the existing `gen_new_gun_twins.js`
   / `gen_apex_twins.js` recipes. Append the new blocks to
   `source_data/acc_weapon_variants.gdt`. (If another session currently owns that GDT, put
   the new blocks in a **separate** `acc_*_twins.gdt` — the War Machine did, in
   `acc_war_machine_twins.gdt` — to avoid clobbering their appends.) A projectile special
   can't go through `apply_recoil_overhaul`/`gen_weapon_variant_gdt`'s bulletweapon path —
   hand-clone its projectile-equivalent fields (Blast-O-Matic / Havoc precedent).
2. `_acc_weapon_variants.gsc::variant_guns()` — add the base name. If the gun is
   **gun-scoped** (only bakes some combos), also add its filter to `form_bakes_suffix()`
   (the turbo/spd/wonder precedents). `variant_up_name()` handles the `_up` PaP name (the
   Thundergun's irregular `thundergun_upgraded` is the one special case).
3. **Zone twin block** — add the `weaponfull,<name>_acc_<combo>` lines for exactly the
   combos you baked, mirroring an existing gun's block (per-form order is alphabetical:
   `<name>_acc_fastreload`, `<name>_acc_recoil50`, `<name>_acc_recoil50_fastreload`, × base
   then `_up`). `build_available_twins()` is generated from `variant_guns()` ×
   `variant_dims()` gated by `form_bakes_suffix()`, so it needs **no** per-gun edit.
4. `gdtdb /update` (`<tools>\gdtdb\gdtdb.exe`, cwd = the `gdtdb` folder), then link.

**Tool-pipeline + backup discipline (the fragile part — get it right).** Whenever you DO
run the base-scaling tools, the canonical order is **restore pristine →
`apply_recoil_overhaul.js` → `reduce_base_ammo.js` → `gdtdb /update` → build**. The
backups are install-side, gitignored:
- `apply_recoil_overhaul` keeps `*.acc-orig` (pristine Skye) per twin-gun and restores
  from it before scaling (idempotent). `reduce_base_ammo` (the global −30% mag/reserve
  cut) keeps `*.acc-ammo-orig` and always reduces FROM it.
- **Adding a gun to `apply_recoil_overhaul`'s `GUNS[]`:** first restore its base GDT to
  pristine and delete BOTH its `*.acc-orig` and `*.acc-ammo-orig` so each tool re-snapshots
  cleanly (else clips double-reduce and recoil gets wiped).
- **When the twin matrix size changes:** `apply_recoil_overhaul` now **self-heals** the
  classic footgun — it deletes the stale `acc_weapon_variants.gdt.acc-ammo-orig` after
  regenerating (so `reduce_base_ammo` re-snapshots the new matrix instead of restoring the
  old twin count). Existing twin guns: do NOT delete their `*.acc-ammo-orig`.
- Only `acc_weapon_variants.gdt` (the twins) is repo-tracked; the Skye base GDTs + all
  `.acc-*` backups + the ×1.75 recoil edit live **install-side** (see the Reproducibility
  gap gotcha). A fresh box needs the packs re-installed and the tool chain re-run.

---

## Adding a new perk/ability weapon-variant AXIS (the extensible framework)

`_acc_weapon_variants.gsc` is a **data-driven, effect-agnostic** swap engine. The swap
mechanics (instant `SwitchToWeaponImmediate`, re-entrancy mute, `true_base()` PaP keying,
`_up`-twin upgrade registration, laststand defer) are **shared and never change**. A new
perk/ability effect is added by declaring an **axis** and baking its **twins**. Each axis
is one independent weapon-stat dimension (recoil, reload, sprint-out, swing speed, …); the
gun a player holds is `<gun>[_up]_acc_<tok1>_<tok2>…` for the active tokens, resolved by
**token SUBSET** (largest-first) so a missing combined twin degrades to a partial effect,
then base. **To add an effect (e.g. a new ability that lowers ADS-in time) do ONLY these —
no core change:**

1. **Bake the twins.** Add a new key-set to `tools/gen_weapon_variant_gdt.js` if your field
   isn't already covered (it scales recoil/reload/etc. GDT key-sets), then hand-generate the
   `<gun>[_up]_acc_<token>` blocks into `source_data/acc_weapon_variants.gdt` (see §8–10 —
   the whole-tool re-run is retired). If the axis is baked for only a subset of guns, gate
   it in `form_bakes_suffix()`.
2. **Zone:** add a `weaponfull,<twin>` line per new twin.
3. **`_acc_weapon_variants.gsc`:**
   - `variant_dims()` — append your axis's token(s) (canonical order = the token order in a
     twin name). Make it the **LAST** dim if it's gun-scoped — `desired_weapon()` drops
     TRAILING tokens on a miss, so every gun without your twins degrades cleanly to its
     other twins (the `turbo` precedent).
   - Write an `axis_<name>()` returning your token when the perk/ability/item is active
     (read `HasPerk`/`has_mega`/the item flag; honor the timed-ability overlay).
   - `init()` — append `&axis_<name>` to `level.acc_variant_axes` (same canonical order).
4. **Build** (full `cod2map64`→LED→linker — the GDT is fastfile-baked). `true_base`/PaP/HUD
   all keep working because they're effect-agnostic; `build_variant_suffixes()` and
   `build_available_twins()` recompute themselves from the dims, so they never drift.

Keep `variant_dims()` order == `level.acc_variant_axes` order. Some wonder weapons need a
per-weapon compat shim so a twin-named copy still triggers its stock script behavior
(e.g. `twin_thundergun_fire_shim()` re-fires the stock fling for `thundergun_acc_*`,
because stock's watcher is `==`-object gated and misses twins — the same finish-the-stock-
pipeline pattern as electric cherry).

---

## Build & verify

```powershell
cd <repo>
node tools/lint_gsc_xref.js                       # GSC cross-refs resolve
# (hand-gen the new gun's twins via your scratchpad script -> gen_weapon_variant_gdt.js, then:)
& "$tools\gdtdb\gdtdb.exe" /update                 # register the new twin assets in gdt.db
.\tools\sync_to_modtools.ps1                       # repo -> usermap (+ share\raw aliases, see gotcha)
& "$tools\bin\linker_modtools.exe" -language english -modsource zm_abandoned_cyber_city
```
- **No geometry changed** → linker only (no `cod2map64`/LED). A **GDT** asset change needs
  `gdtdb /update` first; a `.efx`/`.vision`/GSC-only change does not.
- **Expected exit ≈ `1XXX000`** (known-good baseline): **1 waived `^1ERROR` × 1,000,000 +
  N cosmetic `^3` warnings × 1,000.** The lone remaining waived error is cosmetic-only
  (gun still fires/sounds/damages): the Five-Seven PaP camo `mtl_origins_camo_alt`. The
  `^3` warning count (`N`) **varies build to build** and is NOT a regression signal (a
  clean GSC-only build logged 13 = 12 PhD-Flopper Apothicon-Fury FX segments + 1
  bullet-mesh report, all unrelated to weapons). The old `3003000` baseline's other two
  errors — the AE4 muzzle FX `iw7_efx_plasma_muz_flash` and the Ripper shell-eject FX —
  were FIXED install-side 2026-06-15 (see the FX gotcha), which is why the count dropped
  3→1. **Method:** don't trust the exit number — read the errorlog and confirm the only
  `ERROR:` is the camo and that **none of your new gun's asset ids appear**. A genuinely
  new error adds another 1,000,000 *and* names your gun.
- **FF** at `usermaps\zm_abandoned_cyber_city\zone\zm_abandoned_cyber_city.ff` — confirm
  a fresh `LastWriteTime` and a size bump.
- In-game (`PLAY_NORMAL.bat`, `+set_gametype zclassic`): spin the box, confirm the gun
  appears, **fires with sound**, PaPs, its ability fires on the ADS+melee chord, and — if
  twinned — Deadshot/Speed-Cola Mega visibly swap its recoil/reload profile.

---

## Gotchas (hard-won)

- **Sound aliases must be in `share\raw\sound\aliases\`, not just the usermap.** The
  linker's sound-bank build reads the canonical `share\raw` path; the usermap copy is
  ignored at sound-compile. A cached `.all.alias.sz` hides a missing/stale source
  until **any** source changes — then the WHOLE bank fails to load
  (`sound aliases failed to load`) and every gun goes silent. The szc references
  `user_aliases.csv` + `acc_skye_box_weapons.csv` + `nsz_brutus.csv` (aliases) +
  `ambient_mod.csv` (in `share\raw\sound\ambients\`) — **all** must be present.
  `sync_to_modtools.ps1` now copies `sound/aliases/*.csv` → `share\raw\sound\aliases\`
  for you (COPY, not mirror, so stock sources survive). Verify after sync.
- **GDT filename ≠ weapon name** (`skye_s1_tac-19.gdt` → `s1_tac19`). Use the asset id
  everywhere in script/zone/CSV.
- **PaP `_up` in zone/CSV, the variant tool, and balance** all key off the base name
  via substring/`_up` suffix — one balance line and one `variant_guns()` entry cover
  base + PaP + all twins.
- **PaP camo errors are non-fatal and waived** (the Five-Seven's). A new gun whose PaP
  camo table is self-contained in its GDT (the AK's `t6_camo_ak47_table`) resolves fine
  and adds no error. Don't chase camo (user call).
- **Removing a baked PaP optic/attachment** (a ported `_up` form that ships a reflex/scope
  you don't want): the optic lives as ~9 fields on the `_up` *bulletweapon* block —
  `attachViewModel1/2` (`vm_*_hip_scope`/`*_ads_scope`), `attachWorldModel1`,
  `attachViewModelTag1/2`+`attachWorldModelTag1` (`tag_reflex`/etc.), the optic ADS anims
  (`adsDownAnim`/`adsUpAnim` → the `*_<optic>_ads_*` set), and `hideTags` (the `_up` hides
  the irons via `tag_irons_hide`; the base hides `tag_optic_mount`). Revert all of them to the
  **base** block's values to restore iron sights — leave clip/damage/stock/mag/FX (the real
  PaP upgrades) alone. Do it in a **re-runnable tool** keyed by block name (the install base
  GDT block **and** every `<gun>_up_acc_*` twin in `acc_weapon_variants.gdt`, or the perk twins
  keep the optic), then `gdtdb /update` + `-GscOnly`. Worked example:
  [tools/remove_ppsh_pap_optic.js](../tools/remove_ppsh_pap_optic.js) (PPSH "Pale Rider" mk8
  reflector). **RE-RUN it after regenerating twins** (regeneration restores pristine base +
  re-adds the optic).
- **Ported energy/sci-fi guns can reference FX from a DIFFERENT game's pack.** The AW
  AE4's muzzle flash chains to `iw7_efx_plasma_muz_flash` (an *Infinite Warfare* material).
  With the IW pack absent, the linker logs `Material <fx> not found in gdtDB` — **non-fatal,
  same class as the camo waiver**: the gun fires/sounds/damages, only that one VFX is
  missing. **TRAP:** the broken reference is usually NOT the weapon GDT's
  `viewFlashEffect`/`viewShellEjectEffect` field (that points at a `.efx` that DOES exist) —
  it's a material/atlas string buried *inside* the `.efx` (and its `_efxs` companion) under
  `share\raw\fx\`. Trace it: `grep -rn "<missing-name>" "<tools>\source_data"
  "<tools>\share\raw"` finds the one real site. Fix = repoint that line to an existing
  sibling material in the same `.efx` (or a stock FX). `.efx` files are raw assets compiled
  by the linker directly, so a `.efx` edit needs only a linker re-run — NO `gdtdb /update`.

  **FIX APPLIED — AE4 + Ripper FX (2026-06-15).** Both box guns had a missing-FX `ERROR:`;
  both were repaired install-side (game-rip assets, NOT repo-tracked; `.acc-fx-orig` backups
  kept):
  - **AE4 muzzle flash.** In `share\raw\fx\skye_efx\s1_efx\fx_s1_fusion_muz_flash_efxs.efx`
    one `billboardSprite` (line 884) referenced the missing IW7 material
    `iw7_efx_plasma_muz_flash`; every other element used the present sibling
    `mtl_s1_plasma_muz_flash` (line 308, in `skye_s1_wepcommon.gdt`). Fix = swap that one
    line. Pure `.efx` edit → linker re-run only, no gdtdb.
  - **Ripper shell eject.** A plain **typo**: in `source_data\skye_iw6_ripper.gdt` line 34705
    the PaP-AR form's `viewShellEjectEffect` read `"ffx\\…\h1_shell_eject_57x28.efx"` (`ffx`,
    double-f) while its siblings said `fx\\`. Both the `.efx` and its shell xmodel are
    installed — the only bug was the path typo. Fix = `ffx` → `fx`, then `gdtdb /update`.
    (`tools/fix_cw_shell_eject_fx.js` is the reusable helper for this class.)
- **Convertible / dual-mode weapons (`altWeapon`) need ALL assets + skip the twins.** The
  Ghosts Ripper is 4 GDT assets (smg/ar × base/_up) linked by `altWeapon` (weapon-switch
  toggles mode). Wire ALL 4 `weapon,` zone lines (the altWeapon targets must resolve), but
  only the **primary** (`inventoryType "primary"`) goes in the box/CSV. The `_zm` trap
  bites: the CSV/box use the bare name (`iw6_ripper_smg`), the zone uses the `_zm` asset
  names — follow the pack's ADD-TO files verbatim. Do NOT add it to `variant_guns()` / the
  twin set (a perk-twin swap breaks the altWeapon toggle). One `IsSubStr` balance entry
  covers all 4 assets; map every mode-name in the ability/overclock lists so both modes work.
- **gdtdb.exe is at `<tools>\gdtdb\gdtdb.exe`** (NOT `bin\`); the recoil tool runs it.
- **Skye pack zips can be Deflate64** (.NET extractor fails) — extract with WinRAR
  (`C:\Program Files\WinRAR\WinRAR.exe`).
- **Reproducibility gap:** the Skye GDTs + their `.acc-*` backups + the base-recoil ×1.75
  edit live **install-side** (`source_data\`), not in the repo. Only
  `acc_weapon_variants.gdt` (the twins) is repo-tracked. A fresh box needs the packs
  re-installed and the twin tool chain re-run.

---

## Failure modes — boot crashes & what makes a gun "unsafe"

Adding guns in bulk surfaced **three distinct boot-crash classes**. They are independent —
each one alone crashes the load. The hard rule that fell out of it:

> **Add ONE gun at a time, then boot-test before the next.** With many pending edits you
> cannot bisect a black-screen crash after the fact — you add, sync, build, launch,
> confirm, *then* add the next. This is slow and it is the only thing that works. "I added
> 6 and the game won't boot" cost a full revert.

Screen every candidate for the three modes **before** promising "fully twinned": check the
GDF type (`bulletweapon` vs `projectileweapon` vs permanently-akimbo `dualwieldweapon`) and
the `altWeapon` field. Rejected examples: the CW Nail Gun (`projectileweapon`) and the XMG
(permanent akimbo) both can't take recoil twins; the BO1 AK-74u shipped a live `altWeapon`
launcher (§B). Two guns can still ship **twin-less** (their base + `_up` are box-swapped
as-is).

### A. Twin weapon-count cap (engine access-violation at boot)

Every recoil/perk **twin** is a full weapon-table registration, so a twinned gun costs
`combos × 2 forms` weapon slots. The engine has a hard ceiling on registered weapons and
**silently access-violates past it at load** — not a linker error, the `.ff` builds fine.

- **Live matrix (2026-07-09):** the 2 global axes (`recoil50 × fastreload` = 6 slots/gun)
  on **22 conventional guns = 132**, plus the gun-scoped `turbo` (Havoc only, 8 forms),
  the fastreload-only wonder tier (Mahem/Thundergun/Fire Bow/War Machine), and the
  gun-scoped Leviathan `spd` tier (3 forms) = **≈150 twins**. Recount from
  `_acc_weapon_variants.gsc` `variant_guns()`/`variant_dims()`/`form_bakes_suffix()` — that
  is the only authoritative count. The map `.ff` packed **229 weapon assets total** as of
  2026-07-08 (the total table, twins + base + PaP + stock cooked WWs).
- **Live data points (at the old 46-slots/gun layout):** 5 twinned guns = **230** twins →
  boots; 8 twinned guns = **368** → crashes; 9 = 414 → crashes. So the twin-layer wall sits
  between **230 (known-good)** and **368 (known-bad)**; we treat **~230 as the safe budget**.
- **Crash signature:** black screen on load → minidump faulting module `blackops3.exe`,
  exception `0xC0000005` (ACCESS_VIOLATION) at `blackops3.exe+0x25DF24E`, inside
  `BG_Cache_RegisterWeapon` during weapon registration. **No `console_mp.log` error and no
  errorlog entry** — the build is clean, the engine dies registering the table.
- **Headroom:** at ≈150 twins we are ~80 under the ~230 safe line.
  - **Twin-less guns** (the shipped default — base + `_up` = ~2 slots, akimbo = 3, a
    stock-cooked WW like `tesla_gun` = ~0 of *our* twin budget): cheap, do **not** touch
    the twin budget. The only ceiling is the unmeasured *total*-table size, so **add ONE at
    a time and boot-test**.
  - **Twinned guns** (full recoil/reload handling): **~80 twins free ÷ 6/gun ≈ 13 more**
    before the ~230 safe line. Hard-stop well before 368.
- **To twin a gun beyond the headroom** you must first buy back budget (retire an axis or a
  gun's twins) so the total stays under ~230.
- **Why twin-less is fine:** twins are a polish layer (per-perk recoil/reload feel). A
  twin-less gun still fires, PaPs, sounds, and takes its ability/overclock — it just uses
  one recoil profile across all perk states. Acceptable; ship it.

### B. Attachment `altWeapon` double-`_zm` (`Com_ERROR` on launch) — the AK-74u

The BO1 **AK-74u** GDT carried an under-barrel **launcher** attachment whose `altWeapon`
field pointed at `t5_ak74u_launcher_zm`. At launch the engine appends its own `_zm` to the
*upgraded* attachment form and looks up `t5_ak74u_launcher_zm_zm` — which does not exist:

```
Com_ERROR: could not find altWeapon 't5_ak74u_launcher_zm_zm'
           for attachment 't5_ak74u_up_zm'
```

This is a **hard `Com_ERROR`, not the silent AV** — it appears in the runtime log. The
`.ff` links clean (the attachment asset resolves); the failure is the runtime altWeapon
name-mangling. **Pre-screen every candidate:**

```powershell
Select-String "$tools\source_data\skye_t5_ak74u.gdt" -Pattern 'altWeapon' | ForEach-Object { $_.Line.Trim() }
```

- `altWeapon = ` **empty** → safe.
- `altWeapon = <something>` → that target (and its `_zm`/`_up_zm` forms) **must resolve**,
  or bench it until the launcher/alt attachment is stripped. (Distinct from §-convertibles
  like the Ripper, where the altWeapon is the intended dual-*mode* mechanic and you wire all
  forms — here it's a vestigial attachment we don't want.)

**FIX APPLIED — AK-74u (2026-06-15).** The launcher was a vestigial under-barrel GL we
don't ship, so we severed it install-side: blank the one live `"altWeapon"` string on the
PaP form (`t5_ak74u_up_zm`) → `"altWeapon" ""`, then `gdtdb /update`, then grep the errorlog
for `_zm_zm` (must be 0). The launcher asset stays in the GDT but is never zoned/boxed →
vestigial, harmless. Install-side edit (not repo-tracked). **NOTE:** the AK-74u is now the
Cold War `t9_ak74u` port with the REGULAR `_up` PaP form — the `_up_zm` irregularity is gone.

### C. Twin-tool / mechanic exclusions (caught pre-build, not a crash)

The bulletweapon twin path only twins `bulletweapon.gdf` assets, and the perk-swap itself
breaks certain mechanics:

- **Projectile weapons** — a `projectileweapon.gdf` (CW Nail Gun) has no recoil twin path.
  Add it twin-less, OR (for a special you *want* twinned, like the Blast-O-Matic / Havoc /
  War Machine) **hand-clone its projectile-equivalent fields** into `acc_weapon_variants.gdt`
  (the swap path in `_acc_weapon_variants.gsc` is name-based and works for any weapon class).
- **Dual-wield / akimbo PaP** — the **M1911** and **PDW** PaP to akimbo (`_rdw`/`_ldw`
  forms); a perk-twin GiveWeapon-swap fights the akimbo state. **Zone ALL THREE forms** —
  `weapon,<g>` + `weapon,<g>_rdw_up_zm` + `weapon,<g>_ldw_up_zm` — or the left hand dangles
  when the engine spawns the pair at PaP (there is no plain `<g>_up`). CSV `upgrade_name` =
  the **right-hand** form. Do NOT add to `variant_guns()` (twins break the akimbo toggle).
  - **Akimbo explosive-PaP balance trap.** The M1911's PaP forms are *projectileweapons* at
    ~7000 direct + splash. `acc_weapon_balance_mult` applies to **all** damage (incl.
    explosive), so a broad `IsSubStr("s2_m1911")` buff would scale the PaP to ~24,500/shot.
    Fix = a **more-specific line ABOVE** the base match for the `_rdw`/`_ldw` forms. Always
    check a PaP form's *baked damage* when one `IsSubStr` covers base + an explosive upgrade.

### Boot-crash triage checklist

1. `.ff` built but black screen / instant exit → suspect **A or B**, not the linker.
2. Newest minidump: exception `0xC0000005` at `blackops3.exe+0x25DF24E` → **A (twin cap)**;
   revert the last twin batch.
3. `console_mp.log` last line is `Com_ERROR: could not find altWeapon …_zm_zm` → **B**; that
   gun's GDT has a live altWeapon attachment — bench it.
4. Linker abort `asset "<gun>" ("bulletweapon.gdf") not found` → **C**; the gun isn't a
   bulletweapon — hand-clone its twins or ship it twin-less.
5. Nothing obvious → revert to the last known-good single-gun state and re-add **one**.

---

## Worked example — BO2 AK-47 (`t6_ak47`), 2026-06-14 (historical)

The original worked example, written when the AK-47 was the BO2 `t6_ak47` (it has since
been swapped to the Cold War `t9_ak47` — the wiring is identical). Full-auto AR box gun.
Stats from the GDT: damage 200 (min 175), fireTime 0.08 (750 RPM), clip 30,
`weaponClass rifle`. Wiring applied:

1. CSV: `t6_ak47,t6_ak47_up,,1250,rifle,,,,,TRUE,FALSE,FALSE,,,FALSE,TRUE,rifle,,,`
2. Zone: `weapon,t6_ak47` + `weapon,t6_ak47_up`.
3. Sounds (10 aliases) — cloned from templates:
   ```powershell
   $csv = "<repo>\sound\aliases\acc_skye_box_weapons.csv"
   $text = [System.IO.File]::ReadAllText($csv).TrimEnd("`r","`n")
   $lines = ($text -split "`n") | ForEach-Object { $_.TrimEnd("`r") }
   function Get-Row($n){ $lines | Where-Object { ($_ -split ',')[0] -eq $n } | Select-Object -First 1 }
   function Clone($t,$nm,$sp){ $c=(Get-Row $t)-split ','; $c[0]=$nm; $c[3]=$sp; ($c -join ',') }
   $new = @()
   $new += Clone 'wpn_s1_asm1_shot_plr'     'wpn_t6_ak47_shot_plr'     'skye_ports\t6_ak47\fire\wpn_t6_ak47_shot.wav'
   $new += Clone 'wpn_s1_asm1_shot_npc'     'wpn_t6_ak47_shot_npc'     'skye_ports\t6_ak47\fire\wpn_t6_ak47_shot.wav'
   $new += Clone 'wpn_s1_asm1_pap_shot_plr' 'wpn_t6_ak47_pap_shot_plr' 'skye_ports\t6_ak47\fire\wpn_t6_ak47_pap_shot.wav'
   $new += Clone 'wpn_s1_asm1_pap_shot_npc' 'wpn_t6_ak47_pap_shot_npc' 'skye_ports\t6_ak47\fire\wpn_t6_ak47_pap_shot.wav'
   foreach ($f in 'bolt_back','bolt_forward','charge','futz','mag_in','mag_out') {
     $new += Clone 'wpn_t6_fiveseven_charge' "wpn_t6_ak47_$f" "skye_ports\t6_ak47\foley\wpn_t6_ak47_$f.wav" }
   # append $new, write back UTF8-no-BOM with LF
   ```
4. Box pool: added `"t6_ak47"` to `box_weapons`.
5. Ability: new category `ar` → **Focus Fire** (`effect_focus_fire`, 25 s cd) arming
   `ACC_FOCUS_FIRE_CRIT_SHOTS = 6` (reuses the Precision Mode crit-shots contract).
6. Overclock: `ar_list = array("t6_ak47")` → the AR pool (Burst Coil/Overpressure/…).
7. Balance: `if (IsSubStr(weapon_name,"t6_ak47")) return 0.23;` — the strongest-but-not-
   trivial box reward (AR workhorse).
8–10. Twins: added to the twin set + `variant_guns()`, generated the 6 twins (3 combos ×
   base/_up), added the zone `weaponfull,t6_ak47…` block, `gdtdb /update`.

Result: `lint xref OK`, linker exit `1000000` (waived camo only), FF 29.26 MB.

---

## Appendix — related engine lever: headless perk gating (not a gun step)

Salvaged from the retired docs/21 Radiant section because it's a reusable BO3 hack worth
keeping. Stock `_zm_perks.gsc` calls **`level.custom_perk_validation( player )`** on the
perk-machine trigger (`self`) immediately before it reads `self.cost` and completes a
purchase — `self.script_noteworthy` is the machine's perk. That hook is the lever to
gate/reprice perk buys **entirely in GSC, no Radiant entity needed**. It is now **shipped**
as `_acc_perk_info.gsc::acc_perk_validate` (line 57), used for the Armory (Mega Mule Kick)
**10%-off point-of-sale discount** — per-player, at any range, because the hook runs on the
buying player right before the stock cost read. The same hook could enforce a **4-of-9
per-round perk-rotation lockout** (`return IsInArray( level.acc_perk_rotation,
self.script_noteworthy )`); that lockout is **not built** — the rotation *brain* rolls
(`_acc_map_randomizer::roll_perk_rotation`) but `apply_perk_rotation_to_machines` is a
`TODO(acc-geom)` stub, and only one `custom_perk_validation` slot exists (currently the
Armory pricing). Enable a lockout only on request (it locks 5/9 perks per round — a balance
call).
