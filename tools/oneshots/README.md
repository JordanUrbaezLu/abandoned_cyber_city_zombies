# tools/oneshots — rescued one-shot GDT/balance writer scripts

**What this is:** every surviving scratchpad script that WROTE durable repo/install
state, rescued 2026-07-10 from the Claude session temp dirs (`%LOCALAPPDATA%\Temp\
claude\...`) by the asset-portability red-team audit — they were one Windows
disk-cleanup away from deletion, and the CHANGELOG had (wrongly) declared them gone.
These are the *executable records* of install-side GDT patches whose outputs
otherwise ride only the external-assets zip.

**These are ONE-SHOTS, not maintained tools.** Each was written against the install
state of its day (absolute paths, baked-in field lists). Re-running one blindly can
double-apply a patch — read the header first; most refuse to re-apply or write an
`.acc-*-orig` backup. They are kept for (a) disaster recovery — reapplying a patch
chain to a freshly reinstalled pack, and (b) provenance — knowing exactly what was
changed and why.

**Verified run-order constraints (Apex chain, from the script headers):**
1. `fix_apex_fire_sounds.js` and `fix_apex_recoil.js` — BEFORE `gen_apex_up.js`
   (they edit the APEX_BO3.gdt BASE blocks that gen_apex_up clones).
2. `gen_apex_up.js` — writes `source_data/acc_apex_up.gdt` from the patched bases.
3. Twin/`_up` regenerators (`gen_apex_twins.js`, `gen_havoc_twins.js`,
   `gen_havoc_turbo_twins.js`, `gen_wonder_fastreload_twins.js`,
   `gen_new_gun_twins.js`, `gen_leviathan_spd_twins.js`, `gen_klauser_twins.js`)
   — AFTER all base-GDT patches (they clone base blocks verbatim).
4. `gen_havoc_charge_steps.js` — AFTER `gen_apex_up.js`; generates the
   **abandoned v4** `acc_havoc_chg.gdt` charge-clone approach (live system is the
   v5 script-owned timer in `_acc_havoc_charge.gsc`); kept as the documented v4.4
   revert fallback and the only regenerator of the 3 charge tail wavs.

**Notable single-purpose records:**
- `fix_shotgun_damagerange2.js` — the damageRange2-clamp linker fix (memory
  `shotgun-damagerange2-linker-backwards`) applied to the Skye shotgun GDTs.
- `strip_gdt_blocks.js` — the black_ops_3_fx.gdt dup-block strip from the HB21
  bows integration (writes `.acc-predup-backup`).
- `fix_g7_sfx.js` — the G7 silent-fire repair on `sound/aliases/acc_apex_weapons.csv`.
- `add_decon_alarm.js` — added `acc_decon_alarm` to acc_audio.csv; its wav is a
  game-rip placeholder (civil_protector `police_box_siren.wav`) **flagged for a
  CC0 swap before Workshop publish** (now tracked in CREDITS.md).
- `movespeed_lmg_0709.js`, `reload_balance_0709.js`, `gdt_balance_0709.js`,
  `apply_tuning_20260706.js`, `buff10.js`, `buff_followups.js`, `pk_rof.js`,
  `af_speed.js`, `blasto_ammo_mors_ft_0709.js`, `thundergun_ammo_0709.js` —
  the dated balance passes (see CHANGELOG entries of the same dates).
- `calc_new_guns.js` / `cut_new_gun_clips.js` / `splice_gen_gsc.js` /
  `strip_fastfire_gdt.js` — the XM4/Streetsweeper/CEL-3 new-gun install chain.
- `swap_galil_grav.js` — the Galil→CW Grav migration (2026-07-05).
- `docs_renumber_2026_07_10.js` — the parallel session's docs/ 00-39 renumber +
  cross-ref rewrite (executable record of that rename).
- `ffscan_kf.js` — kill-feed .ff string verifier (superseded by `tools/ff_grep.js`,
  kept for its ZM_AETHERIUM_KF_* needle list).
- `chalk_sheet.js` — chalk-icon contact-sheet auditor (companion to
  `tools/whiten_chalk_icons.js`).

**CONVENTION going forward (the lesson):** any scratchpad script that WRITES repo
or install state gets copied into `tools/oneshots/` in the same session that ran
it. Scratchpads are temp storage — treat a writer script left there as data loss
in progress.
