# docs/research — raw research dossiers (committed knowledge base)

Raw output of the deep-dive research agents (2026-06-12 ultracode passes).
Each file is a verified-with-citations dossier on one stock/shipped system.
**These are the receipts behind the `VERIFIED(acc)` comments in code** — when
a stock interface question comes up, grep here before re-deriving.

Convention (saved as a standing rule): every finding from exploring external
codebases gets documented durably —
- **Synthesized technique** → [docs/16_community_techniques.md](../16_community_techniques.md)
  (the ledger: mechanism + citation + applicability)
- **Raw dossier** → this folder (+ a line in this index)
- **Design-level map study** → [docs/13_reference_maps_study.md](../13_reference_maps_study.md)
- **Load-bearing trap for every session** → CLAUDE.md hard-won facts

## Index

| File | Topic |
|---|---|
| `BO3_stock_zone_manager_zm_zonemgr_gsc_.txt` | Zone declaration KVPs, add_adjacent_zone API, activation semantics, manage_zones flow, spawner architecture |
| `BO3_usermap_buyable_door_debris_author.txt` | Complete buyable door/debris recipe: trigger + piece KVPs, movement types, script_flag→zone chain, electric doors |
| `BO3_Mystery_Box_Radiant_anatomy_multi_.txt` | Mystery Box anatomy (zbarrier + struct pair), multi-chest start selection, box-move/teddy logic, acc_box_* scheme validation |
| `BO3_stock_power_switch_system_zm_power.txt` | Power switch entity contract, multi-switch support, power zones (script_int), the two-switch A/B plan |
| `BO3_stock_round_spawning_flow_actor_spa.txt` | Round spawning pipeline, spawner↔riser-struct relationship, manual spawn_zombie patterns, zombie_init_done trap, boss durability flags |
| `Stock_BO3_zm_perks_gsc_vending_trigger_.txt` | Perk vending trigger flow, already-owned interception (Mega hook), give/lose/re-give lifecycle, Jug health + speed mechanisms |
| `BO3_stock_powerup_system_drop_API_cust.txt` | Powerup drop API, custom pickup patterns |
| `MattFiler_zm_alien_isolation_shipped_BO.txt` | Shipped-map wiring: zones array, custom doors, single box, spawner counts, runtime spawn relocation |
| `_acc_mega_bottles_gsc_implementation_aud.txt` | Clientfield GSC/CSC pairing proof (toplayer = both VMs or crash; clientuimodel = safe GSC-only), hudelem greybox HUD recipe |
| `weapon_import_research_raw.json` | Raw weapon-import research (sweeps + 23 URL verdicts) behind docs/21 |
