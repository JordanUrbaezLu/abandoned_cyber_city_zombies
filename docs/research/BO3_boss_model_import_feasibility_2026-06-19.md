# BO3 boss-model import feasibility (Panzer / Margwa / Mangler / etc.) — 2026-06-19

Multi-agent research (7-boss install probe + adversarial verify + synthesis), grounded in the
ACTUAL Mod Tools install on this box, not assumptions. Supersedes the stale "all DLC bosses are
blocked" framing in memory `boss-model-constraint-and-phantom`. Method: probe `share/raw` (archetype
scripts, animstatemachines, behavior, FX), the live `gdtdb/gdt.db` (160 MB — greppable; presence ⇒
toolchain-reachable), `model_export/`, and the repo's own dossiers; the **`gdt.db` grep test** is the
decisive oracle (`c_zom_mech_body` = 27 hits vs `c_zom_margwa*` = 0 → mechz reachable, margwa not).

## Bottom line

Only the **Spiki standalone Panzer (mechz)** is realistically importable here — its assets are
physically installed and the scripts are already vendored. Everything else is either **asset-locked**
behind an external pack you must source + import via APE/gdtdb (Margwa, Thrasher, Spider, Keeper), or
**not a BO3 enemy at all** (Mangler). Our one *proven* working custom boss remains **NSZ Brutus**.

## Ranked feasibility

| Boss | In this install? | Importable? | Who does it | Effort | Verdict |
|---|---|---|---|---|---|
| **Brutus** (shipped) | YES — installed + wired | DONE | n/a | none | Working baseline |
| **Panzer Soldat (mechz)** | YES — xmodel + 301 xanim + GDT in live `gdt.db` (Spiki pack); scripts vendored | Yes, **with GUI** | Me: zone aitype/asset lines + anti-inert assetlist fix + re-version DLC5→SHIP clientfields + GSC glue. You: place spawner in Radiant, full LED build, **playtest the attack-crash** | medium | **importable_with_gui** |
| **Thrasher** (DLC2) | scripts+graph+FX yes; **model+xanim ABSENT** | only after you source assets | You: pack (Spiki #3087) + APE import; then me: zone+GSC | high | **asset_locked** |
| **Margwa** (Shadows of Evil) | scripts+ASM+behavior+FX+sound yes; **model+creature-xanim+aitype ABSENT** | only after you source assets | same as Thrasher | high | **asset_locked** |
| **Spider** (DLC2) | enum token + anim tables + FX only; **no archetype script/model/xanim** | only after you source assets | same (worse — no behavior script) | high | **asset_locked** |
| **Keeper/Protector** (SoE/DLC4) | enum constant + some wiring; **no archetype script/model/creature-xanim/aitype** | only after you source assets | same | high | **asset_locked** |
| **Mangler** | NO — not a BO3 enemy | No (cross-game rip only) | neither, w/o full Maya re-rig | blocked | **not_in_bo3** |

## Key facts (verified)

- **Panzer (mechz) is NOT DLC-locked here — the memory was stale.** The Spiki Panzer pack is installed:
  `c_zom_mech_body` (5.8 MB) + armor/faceplate/claw/powersupply (LODs), 301 `XANIM_BIN`,
  `mechz_*.ai_asm`/`.ai_bt` graphs, `mechz_{claw,tomb}.atr`, stock `dlc1/castle` `fx_mech_*`; GDTs imported
  into `gdt.db` (`archetype_zm_mechz` = 6 hits, `c_zom_mech_body` = 27). Scripts vendored:
  `scripts/zm/mechz_spiki.gsc/.csc`, `scripts/zm/zm_abandoned_cyber_city/_acc_boss_panzer.gsc`.
  - Headless half (me): add `aitype,archetype_zm_mechz_genesis`/`_tomb` + `c_zom_mech*`/`fx_mech*` lines to
    the `.zone` (absent today); the Spiki "comment duplicate gsc/csc lines in assetlist" anti-inert fix;
    **re-version the clientfields** — `mechz_spiki.csc:54-60` + `mechz_spiki.gsc:94-99` register at
    `VERSION_DLC5`/hardcoded 15000, which a usermap (`VERSION_SHIP`) can't use; finish the spawn glue.
  - GUI half (you): place `actor_spawner_zm_castle_mechz` (`targetname mechz_genesis_spawner`) +
    `acc_panzer_spot` in Radiant (the `.map` has ZERO mechz strings today → `_acc_boss_panzer.gsc:57-60`
    just logs "no spawner placed" and returns); full cod2map64+LED+linker build; **in-game playtest the
    unfixed attack/being-attacked CRASH** (rooted in the `MECHZ_FACE` facial-overlay anim path). Dossier
    verdict = *experiment-only*; treat as a test branch, not a ship commitment.
- **Margwa/Thrasher/Spider/Keeper = asset-locked (scripts present, ART absent).** Base-game ownership
  (Shadows of Evil) does NOT equal toolchain reachability — `gdt.db` has 0 `c_zom_margwa` hits. The 17
  on-disk `ai_zombie_zod_margwa_smash_react_*` anims are a red herring (the *player* getting smashed, bound
  to the player rig). Everything ships EXCEPT model xmodels + creature xanims + (Margwa) an aitype. Need an
  external pack (Spiki #3087) imported via APE/gdtdb — GUI work, identical to the Brutus flow.
- **Mangler = not in BO3.** It debuted in Cold War Firebase Z (2021). Every "mangler" string here is the
  **RAZ Armored Zombie's** left-arm torpedo *weapon* (Gorod Krovi DLC3); every community "Mangler" spawner
  aliases aitype **`raz`** (`gdt.db`: `mangler` = 0, `raz` = 520). A real Mangler = cross-game rip + full
  Maya re-rig + new behavior (multi-week + IP). **If you want the vibe, the in-engine answer is the BO3 RAZ**
  (needs its own DLC3-asset probe to confirm it's installed here).

## Recommendation

Attempt the **Spiki Panzer (mechz) on a throwaway test branch** — the only candidate whose assets are
already on this box. I do the headless half; you place the spawner, run the full LED build, and playtest
the attack-crash. If it reproduces (no published fix), **fall back to the proven path**: re-theme the
working **Brutus**, or import Spiki's *standalone* Panzer #3087 (own GDT/aitype, sidesteps the DLC
clientfield wall) as a second Brutus-class self-contained boss.

**IP/credit (mirror Brutus):** ripped packs are unlicensed → keep OUT of git (gitignored + a row in
`tools/external_assets_manifest.ps1`, gated by `tools/check_external_assets.ps1`), add a 🔴 provenance row
in `CREDITS.md`, keep the Workshop item Private until the IP/credit review, and land CHANGELOG + docs in
the same commit as any wiring.

Relevant files: `scripts/zm/zm_abandoned_cyber_city/_acc_boss_panzer.gsc`, `scripts/zm/mechz_spiki.gsc`/`.csc`,
`zone_source/zm_abandoned_cyber_city.zone`, `map_source/zm/zm_abandoned_cyber_city.map`,
`scripts/_NSZ/nsz_brutus.gsc`, `tools/external_assets_manifest.ps1`, `CREDITS.md`,
`docs/research/BO3_Panzer_mechz_usermap_method.txt`.
