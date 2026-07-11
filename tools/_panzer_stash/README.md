# Panzer (mechz) stash — recovered 2026-07-03

Recovered from git (`84e98c9`, last tree before the 2026-06-22 deletion) after the original
`tools/_panzer_stash/` was lost with the old box. **These are the RAW DECOMPILED pack scripts**
(lost strings: `function_26beb37e`, `var_fa14536d`, DLC5 clientfields) — the 2026-06-19
clean-room fixes were never committed and must be RE-APPLIED from the CHANGELOG recipe below.

## History (CHANGELOG 2026-06-19, "PANZER (mechz) boss spawns at Plaza")

The integration WORKED — verified in-game: the Panzer spawned at Plaza. What made it work
(re-apply all of these):

1. **Attack-crash fix** (the historical killer, why "every time we add it the game breaks"):
   stock `mechz.gsc` registers `mechz_face` at VERSION_SHIP and SETS it on attack/death/idle/pain,
   but the usermap client never registers it → set-on-attack = clientfield layout desync crash.
   FIX: re-bind the 4 face StartFunctions (`mechzAttackStart`/`Death`/`Idle`/`Pain`, name-bound via
   `BT_REGISTER_API`, last-write-wins) to a no-op so `mechz_face` is never set.
2. **Call `mechz_spiki::mechz_health_increases()`** before spawning (defined-but-never-called in
   the pack → otherwise HP = undefined).
3. **Spawner classname** = `actor_archetype_zm_mechz_genesis` (the `actor_<aitype>` pattern).
   `actor_spawner_zm_castle_mechz` is a DLC class this install REJECTS ("not a valid aitype").
4. **Zone lines**: `aitype,archetype_zm_mechz_genesis` (its `.ai_asm`/`.ai_bt` are on disk once the
   pack is installed) + the mechz xmodels/fx. `.ff` grows ~+4 MB.
5. **Comment the duplicate boss gsc/csc lines in `zone_source\all\assetlist`** (per Spiki: fixes
   "spawns but won't move / ignores player").
6. Waived/cosmetic linker noise: `gfx_spark_blink_anim_pcloud_em` (from `fx_mech_dmg_sparks`) +
   `mechz.zpkg`. Trim `fx_mech_dmg_sparks` for a clean log.
7. Boss-side: Brutus CTD-safety flags (`acc_boss_custom_speed`, `ignore_enemy_count` etc.).

Also from the deep-dive (docs/research/BO3_Panzer_mechz_usermap_method.txt): ship the STANDARD
variant only (the Origins variant's grab is inescapable); destructible armor doesn't function
(treat as a solid-armor boss); install exactly ONE panzer GDT (conflicts with HarryBo21's).

## Assets (NOT in git — unlicensed game-rip, gitignored like all packs)

Spiki's Asset Dump (Most AI), modme thread #3087 — link verified LIVE 2026-07-03:

- Base pack:   https://mega.nz/#!Clh0VYCY!gS1r0bmJLQb6VQAq2dcNs3i4zbMRohTY8S5fIyoDhzU
- Update 2020-07-28: https://mega.nz/file/65Aj3aRB#mjw-His7ZbGUs974tVRC8XbziAGlaIgEjn19NpqAgs8
- Password: `Chungus4Prez`

Manifest entry: `tools/external_assets_manifest.ps1` ("Panzer / mechz", marker
`source_data\mechz_spiki.gdt`). The "ADDITIONAL ASSETS DLC" note on the thread applies to
spiders/wasps/margwa only — NOT the Panzer.
