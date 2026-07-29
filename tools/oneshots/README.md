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
  `whiten_chalk_icons.js`, archived here 2026-07-12).

**CONVENTION going forward (the lesson):** any scratchpad script that WRITES repo
or install state gets copied into `tools/oneshots/` in the same session that ran
it. Scratchpads are temp storage — treat a writer script left there as data loss
in progress.

---

## 2026-07-12 audit archive — spent MAP-GEOMETRY + weapon-GDT one-shots (96 files)

Moved out of `tools/` root by the full-repo audit (see `docs/42_code_audit_2026-07-12.md`). Every one
WROTE durable state that is **already baked** into `map_source/zm/zm_abandoned_cyber_city.map`
(geometry / lights / entities / materials) or into the install-side GDTs (`source_data/` + the
external-assets zip). **None is invoked by any `.ps1` pipeline** (verified by a basename grep across all
`*.ps1` before the move) and no kept root tool `require()`s any of them — they are one-shot construction
*records*, kept for provenance + disaster recovery, not maintained tools. `git log --follow` on any file
recovers its exact history. Families moved:

- **Geometry adders:** `add_avogadro_spawn`, `add_ceilings`, `add_corp_trench`, `add_ec_right_wall`,
  `add_lockdown_seals`, `add_perk_alcoves`, `add_pit_room`, `add_power_switches`, `add_room_boxes`,
  `add_trench_bridge`, `add_trench_floor`, `add_trench_rooms`, `add_under_room`, `add_vault_ceiling`.
- **Geometry / light / interactive generators:** `gen_abyss_doors`, `gen_abyss_layer`, `gen_corp_trench`,
  `gen_descent_hub`, `gen_neon_lights`, `gen_paradise_props`, `gen_plaza_basement`, `gen_plaza_shrink`,
  `gen_relocate_exo_room`, `gen_room_cover`, `gen_room_roofs`, `gen_trench_walls`, `gen_underground_lights`,
  `gen_upper_room`, `gen_interactives`, `gen_t9_attach_mats`, `_gate_sealed_lights`, `_grade_abyss_lights`.
- **apply / carve / paint / remove / normalize map mutators:** `apply_entity_moves`, `apply_room_shrink`,
  `apply_zone_greybox`, `apply_zone_materials`, `carve_arena_wing`, `carve_south_concourse`, `carve_wing`,
  `paint_doors`, `paint_plaza_walls`, `paint_region`, `paint_walls`, `remove_guard_rails`, `remove_obstacles`,
  `remove_walls_in_region`, `normalize_box_brushes`, `normalize_gun_loc`, `normalize_mors_loc`,
  `normalize_sniper_loc`.
- **One-shot geometry fixes + the bridge/trench-build saga:** `fix_box_positions`, `fix_bridge_material`,
  `fix_led_safe_geometry`, `fix_paladin_loc`, `fix_perk_facing`, `fix_perk_facing_flanks`,
  `fix_twin_attachments`, `fix_twin_ammo_drift`, `fix_inverted_gunkick_pitch`, `fix_pdw_akimbo_ammo`,
  `fix_cw_shell_eject_fx`, `bisect_brushes`, `bridge_v2`, `convert_bridge_to_brushmodel`, `levers_onto_bridge`,
  `clean_plane_points`, `dedup_guids`, `expand_core`, `fill_trench_rooms`, `single_wall_switch`, `strip_blocks`,
  `strip_entities`, `strip_lighting_entities`, `pack_lightmap_uvs`, `place_boxes_against_walls`,
  `respace_perk_alcoves_10`, `regen_trench_stairs`.
- **Install-side weapon / GDT / alias one-shots:** `prep_apex_tripletake_gdt`, `prep_hamr_gdt`, `prep_m16_gdt`,
  `scale_hipspread_by_class`, `scale_sniper_hipspread`, `symmetrize_cw_recoil`, `rebalance_pap_forms`,
  `reduce_base_ammo`, `graft_cw_weapon_stats`, `restore_cw_mag`, `trim_cw_aliases`, `gen_weapon_variant_gdt`,
  `gen_actionfigure_speed_twins`, `gen_box_dynamic`, `gen_box_weapon_sounds`, `gen_cw_box_aliases`,
  `whiten_chalk_icons`, `remove_ppsh_pap_optic`.
- **`gen_reflection_probes` (special):** archived like the rest, **but** reflection probes are conceptually
  re-derivable (unlike pure geometry). If probe placement ever changes, regenerate with this script AND run a
  FULL `build_map.ps1` **with the LED bake** (per CLAUDE.md's bake gate) — a `-GscOnly` build will not re-bake them.

**Kept in `tools/` root despite matching names** (do NOT archive): `gen_rooms` / `gen_zone_greybox`
(referenced by `preflight_windows.ps1`), the restore-chain regenerators (`gen_perk_glow_fx`,
`apply_recoil_overhaul`, `gen_t7_carve_gdt`, `fix_actionfigure_port`), the maintenance re-run tools
(`add_prop_clips`, `align_box_clips`, `add_rpd_pap_sight`), and all repeatable diagnostics/audits/generators.

## 2026-07-24 content drop (D13 Sector + HB21 heroes + shield reskin + slots)

Run order for a fresh reinstall of these packs (all install-side; details in
`tools/external_assets_manifest.ps1` entries + memory `content-drop-2026-07-24-*`):

1. `mega_dl.js <mega-url> <out>` — headless MEGA downloader (needs `npm i megajs`); the
   D13 + HB21 packs came from live MEGA links 2026-07-24.
2. D13 GDT accu fix — `sed` rpg.accu → default.accu in `source_data/koentje/koentje_disk_gun.gdt`
   (silent-drop trap; no script — two sed lines, see the manifest entry).
3. `fix_discgun_wavs.js` + `verify_discgun_csv.js` — rebuild/verify the trimmed
   `sound/aliases/discgun_sounds.csv` (16/18 pack wavs never shipped; donors = apex b3wing /
   spike_launcher lfe / disc foley). Repo copy is canonical; deploy to share\raw.
4. `dedup_hb21_gdts.js` — strip HB21 GDT blocks duplicating stock/installed GDTs, EXCEPT:
5. `rebuild_gauntlet_gdt.js` — the gauntlet GDT dedup MUST use this (header-anchored):
   the beam names also appear as FIELD VALUES inside the weapon blocks and an indexOf
   stripper corrupts the file (86/85 braces, both gauntlet weapons silently vanish from
   gdtdb → `BG_LoadWeaponVariantDefFile: unable to locate asset` only in -verbose).
6. Whelp soundDef blank — `c_zom_dlc3_dragon.gdt` `"soundDef" "veh_parasite"` → `""`
   (dangling vehiclesounddef link error).
7. `gen_shield_reskin_gdt.js` — regenerates `source_data/acc_riotshield_reskin.gdt`
   (repo + install) from the installed logical_models_crafting.gdt template.
8. `adapt_skull.js` — regenerates the vendored `_zm_weap_keeper_skull.gsc/.csc` CF surgery
   from the pack staging copy (repo files are canonical; only re-run on a pack re-vendor).
9. `add_nav_volume.js` — ONE-SHOT (idempotent, skips if present): the map-covering
   nav_volume the whelp needs. Geometry → FULL build with the LED bake.
