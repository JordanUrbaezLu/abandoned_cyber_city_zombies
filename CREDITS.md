# Credits & Asset Provenance

Provenance ledger for every non-code asset shipped in the Workshop `.ff`. Policy
(see [docs/29 §8](docs/29_atmosphere_and_materials.md#8-licensing-policy-we-publish-to-steam-workshop)):
ship **only** stock BO3 assets, our own original work, or **CC0** assets. **Never**
ship textures.com / Poliigon / Quixel-Megascans/Fab, or assets lifted from another
community map. CC0 needs no attribution, but we record it here for provenance
(takedown-defense) and to honor the creators.

## Current shipped visual assets

| Asset | Source | License | Notes |
|---|---|---|---|
| Wall material `t7_concrete_bare_weathered_01_dark` | Stock BO3 (`t7_concrete.gdt`) | Treyarch (in base install) | greybox wall skin |
| Floor material `t7_concrete_floor_garage_cracked_wet_nw` | Stock BO3 (`t7_concrete.gdt`) | Treyarch (in base install) | wet ground skin |
| Sky `skybox_default_night` + SSI `default_night` | Stock BO3 | Treyarch (in base install) | interim night sky |
| Reflection probes, fog (`SetVolFog`) | Original (this project) | — | our `.map` entities + `_acc_atmosphere.gsc` |

## Current shipped audio assets (CC0)

Authored audio is **CC0** (safe to bundle in the Workshop `.ff`); recorded here for
provenance and to honor the creators. Converted to **48 kHz / 16-bit PCM WAV** for
the BO3 sound build; source WAVs tracked in `sound_assets/acc/`.

| Alias | File | Source | License | Use |
|---|---|---|---|---|
| `acc_main_theme` | `sound_assets/acc/music/main_theme.wav` | **lnplusmusic** — "Suspense Dark Thriller Music" (Pixabay #392762) (user, 2026-06-24; replaced StockTune "Ethereal Neon Odyssey") | ⚠️ **VERIFY before publish** — Pixabay Content License is royalty-free and permits bundling inside a larger work, but Pixabay forbids redistributing the audio as a *standalone* file; confirm it permits Workshop redistribution, or swap to a confirmed-CC0 track. | main theme; plays once at game start (full ~1:45 track; stock ZM music disabled) |
| `acc_amb_city_bed` | `sound_assets/acc/amb/city_bed.wav` | Joth — "Ambience Pack 1: Sci-Fi Horror" (*Infestation in the Control Room*) ([OpenGameArt](https://opengameart.org/content/ambience-pack-1-sci-fi-horror)) | CC0 | global ambient bed (dvar `acc_amb_on`) |
| `acc_shard_pickup` | `sound_assets/acc/fx/diamond_found.wav` | liecio — "Diamond Found" ([Freesound #190255](https://freesound.org/s/190255/)) (user-supplied 2026-06-24; trimmed 5.7s→2.5s + 48 kHz) | ⚠️ **VERIFY before publish** — confirm the Freesound license is CC0 (or record CC-BY attribution). | Data Shard pickup blip (`grant_player`, cache loot) |
| `acc_bottle_pickup` | `sound_assets/acc/fx/glass_cling.wav` | Freesound Community — "Glass Cling 01" ([Freesound #103677](https://freesound.org/s/103677/)) (user-supplied 2026-06-24; 48 kHz) | ⚠️ **VERIFY before publish** — the *freesound_community* uploader is typically CC0; confirm and record. Also used by `evt_bottle_dispense` (bottle drink at a machine). | Mega Bottle pickup chime (`grant_bottle`, boss kill) |
| `acc_ee_song` | `sound_assets/acc/music/ee_song.wav` | **Lilex** — "Cyber Dreams" (user-supplied 2026-06-24; 48 kHz mono) | ⚠️ **VERIFY before publish** — confirm Lilex's licence permits Workshop redistribution (CC0/royalty-free), or swap to a confirmed-CC0 track. | CENTER teddy-bear jukebox song; plays 2D on activating the center bear in the NORTH trench room (`_acc_ee_song.gsc`) |
| `acc_ee_song_2` | `sound_assets/acc/music/ee_song_2.wav` | **the mountain** — "Cyber Security" (Pixabay #144111) (user-supplied 2026-06-25; 48 kHz mono) | ⚠️ **VERIFY before publish** — Pixabay Content License (see `acc_main_theme` row); confirm it permits Workshop redistribution, or swap to a confirmed-CC0 track. | LEFT teddy-bear jukebox song (`_acc_ee_song.gsc`) |
| `acc_ee_song_3` | `sound_assets/acc/music/ee_song_3.wav` | **Rosa Walton / Hallie Coggins** — "I Really Want to Stay at Your House" (Cyberpunk: Edgerunners / CD PROJEKT RED) (user-supplied 2026-06-25; 48 kHz mono) | 🚫 **DO NOT PUBLISH** — copyrighted commercial track, **not** licensed for redistribution. TEST-ONLY. MUST be swapped for a confirmed-CC0/licensed track before the Workshop item goes Public. | RIGHT teddy-bear jukebox song (`_acc_ee_song.gsc`) |
| `acc_brutus_music` | `sound_assets/acc/music/brutus_music.wav` | **alperomeresin** — "The Final Boss Battle" (Pixabay #158700) (user, 2026-06-24; replaced the prior boss loop) | ⚠️ **VERIFY before publish** — Pixabay Content License (see `acc_main_theme` row); confirm it permits Workshop redistribution, or swap to a confirmed-CC0 track. | boss-battle music; loops on Phantom spawn (`acc_boss::boss_music`). Alias keeps the historical "brutus" name |
| `acc_paradise_music` | `sound_assets/acc/music/115.wav` | **Treyarch / Kevin Sherwood** — "115" (Call of Duty: Black Ops Zombies) (user-supplied 2026-06-25; 48 kHz) | 🚫 **DO NOT PUBLISH** — copyrighted commercial track, **not** licensed for redistribution. TEST-ONLY (gitignored, like the game-rip asset packs). MUST be swapped for a confirmed-CC0/licensed track before the Workshop item goes Public. | Paradise BATTLE anthem; loops at max volume during the 4-min onslaught (`_acc_paradise::start_finale_music`) |
| `acc_paradise_calm` | `sound_assets/acc/music/paradise_calm.wav` | **Nintendo** — Super Mario "Stage Win" fanfare (via QuickSounds.com) (user-supplied 2026-06-25; 48 kHz) | 🚫 **DO NOT PUBLISH** — copyrighted commercial sound, **not** licensed for redistribution. TEST-ONLY. MUST be swapped before Public. | Paradise CALM victory fanfare + the WIN sting (one-shot, `_acc_paradise::play_calm_music` / `win`) |
| `acc_phantom_zap` | `sound_assets/acc/fx/electric_zap.wav` | Freesound Community — "Electric Zap 001" ([Freesound #6374](https://freesound.org/s/6374/)) (user-supplied 2026-06-24; 48 kHz mono) | ⚠️ **VERIFY before publish** — the *freesound_community* uploader is typically CC0; confirm and record. | Phantom chain-special hit SFX (`_acc_elites::acc_phantom_chain_zap`) |

## Third-party enemy / character assets (game-rip — IP review before Public)

These are community ports of ripped Treyarch/other-studio assets. They build and
ship fine (they pack as model/aitype dependencies), but carry **no real
redistribution licence** — resolve the IP question and credit each author **before
flipping the Workshop item Public** (start Private). Same caveat the project already
records for Brutus.

| Asset | Source / author | Provenance | Notes |
|---|---|---|---|
| Charred horde reskin (`archetype_charred_zombie`, `c_zom_charred_zombie` + gibs) | Logical's Charred Zombie Pack (Logical; Greyhound/HydraX by Scobalula) | 🔴 Treyarch DLC3 sentinel body + DLC4 charred head, recoloured | base-horde skin; both roster spawners remapped (CHANGELOG 2026-06-14) |
| Perk-bar HUD icons (`i_acc_perk_*` base/mega, incl. `i_acc_perk_cherry_*` from `exo_cherry`) | Ronan's Cyberpunk Shaders (Ronan) | 🔴 derivative — pack readme credits Treyarch (perk designs) + Anna Kuźmińska + CD Projekt Red | custom LUI perk bar (`acc_hud.lua` `CoD.AccPerkBar`); GDT `source_data/acc_perk_shaders.gdt`. Pack readme: **"Remember to credit"** — credit Ronan + the above before Public |
| Action Figure melee (`t8_melee_figure` + `t8_actionfigure_melee`) | T0nic's BO4 melee port (T0nic) | 🔴 Treyarch **BO4 (t8)** weapon model + anims, ported to BO3 | box S-tier weapon + dev give; source gitignored (`tools/external_assets_manifest.ps1`), linker-patched by `tools/fix_actionfigure_port.js`. **Credit T0nic + Treyarch before Public** |
| NSZ Brutus mini-boss (`zm_brutus` aitype — model, anims, FX, sounds, GSC, GDT) | NSZ Brutus pack v1.0.4 (NateSmithZombies) | 🔴 Treyarch **BO2** Brutus model + author's custom anims/FX/sounds | r4/r10/r20 mini-boss; pack gitignored (`tools/external_assets_manifest.ps1`, marker `model_export\_NSZ`). **Credit NateSmithZombies + Treyarch before Public** |
| Civil Protector ally robot (`archetype_ally_zod_robot_companion_ar`/`_gold_ar` — 2 models, 441 anims, ASM/BT, FX, sounds, scripts) | HarryBo21's Civil Protector v2.0.0 (HarryBo21; pack credits ~50 contributors incl. TheSkyeLord, Scobalula, DTZxPorter — full list in pack `INSTRUCTIONS.txt`) | 🔴 Treyarch **BO3 SoE (zod)** robot model/anims + author's companion AI system | round-1 TEST spawn (2026-07-02); scripts vendored (`scripts/zm/zm_zod_robot.*` etc.), assets gitignored (`tools/external_assets_manifest.ps1`, marker `model_export\black_ops_3\c_zom_zod_robot_protector`). **Credit HarryBo21 + the pack credits list + Treyarch before Public** |
| Skye weapon ports (Tac-19, Five-Seven, ASM1, AE4, Galil, Olympia, Chicom, PPSH, MK14, MORS, RW1, Ripper, + FAL) | Skye's Weapon Ports to BO3 (TheSkyeLord + LilRobot) | 🔴 Treyarch / Sledgehammer **BO2/BO3/AW/VG** weapon models + anims, ported to BO3 | box + wall-buy guns; pack gitignored (marker `model_export\skye_ports`). **Credit TheSkyeLord + LilRobot + the original studios before Public** |
| BOCW Cold War weapon ports (`t9_ak47` AK-47, `t9_ak74u` AK-74u, `t9_m60` M60, `t9_rpd` RPD) | **TheSkyeLord's CW pack** (author question RESOLVED 2026-07-02 — the new-box reinstall sources these from Skye's Cold War full pack; the old untraceable `t9_wpn_ports` port is retired, its twins regenerated from Skye's GDTs) | 🔴 Treyarch **BOCW (Cold War, `t9`)** weapon models + anims, ported to BO3 | box guns; pack gitignored (covered by the Skye pack manifest entry, marker `model_export\skye_ports`). **Credit TheSkyeLord + Treyarch (BOCW) before Public** |
| Electric Cherry vending machine (`electric_cherry_model` + 3 materials / 12 textures) | [West] Community Perk Collection v2.7 (Westchief596; machine-model templates: Betiroval, F3ARxReaper666, HarryBo21) | 🔴 Treyarch **BO2 (Mob of the Dead / Alcatraz)** Electric Cherry machine, retextured (the model's skinOverride remaps the original `mtl_p6_zm_*` materials) | the real EC perk-machine model (`_acc_perk_electric_cherry.gsc`; replaced the `p7_lab_bio_machinery_01` stand-in 2026-07-01). **EC-machine-only lift** — the 60-perk pack itself is NOT installed. Pack gitignored (`tools/external_assets_manifest.ps1`, marker `source_data\acc_west_electric_cherry.gdt`). **Credit Westchief596 + Treyarch before Public** |
| Toxic boss skins (`c_sat_zmb_zombie_toxic_1/_2`) | SAT Toxic Zombies (WetEgg; FX assist Rayjiun; tools Cordycep/Saluki by Dest1yo, echo000, Scobalula, DTZxPorter) | 🔴 Treyarch-derived zombie bodies, retextured toxic | Glitch Stalker + Phantom boss skins (model-only lift 2026-07-02; pack AI system NOT installed). Pack readme: "Please credit WetEgg". **Credit WetEgg + Treyarch before Public** |
| Underground horde reskin (`c_t8_zmb_mob_zombie_body1-3` + `head1-4`) | BOTD Zombies (Kingslayer Kyle; Wraith/Greyhound by DTZxPorter/Scobalula) | 🔴 Treyarch **BO4 (Blood of the Dead)** Alcatraz prisoner zombies, ported to BO3 | every zombie spawning below base level (trench/under-rooms/abyss/Paradise) wears a random body+head combo (`_acc_trench_skins.gsc` SetModel+Attach, model-only lift 2026-07-03; the pack's spawner NOT used). Readme: **"Make sure you credit me"**. Zeroy's 54i pack = installed A/B fallback (first pick, rendered headless); ninjaman's HD Ascension = uninstalled 2nd fallback. **Credit Kingslayer Kyle + Treyarch (BO4) before Public** |
| BO1 Thundergun (`thundergun_zm` override: model/anims/sounds) | TheAllNightFall's t5 Thundergun port | 🔴 Treyarch **BO1** Thundergun, ported (overrides the stock BO3 asset names in place) | the box wonder weapon's classic look/sound (2026-07-02). **Credit TheAllNightFall + Treyarch (BO1) before Public** |
| CW/BO6 Pack-a-Punch machine (`p9_fxanim_zm_gp_pap_xmodel`) | ALXS CW-BO6 PAP v1.1.2 (ALXS; model/anims Madgaz + Owen C137) | 🔴 Treyarch **BOCW (Cold War)** PaP machine rip | both PaP machines' visible model (model-only lift 2026-07-02; pack script/sounds NOT installed). **Credit ALXS + Madgaz + Owen C137 + Treyarch (BOCW) before Public** |
| CW skybox (`skybox_t9_mp_miami` + 15 siblings installed) | Nastian — T9 Skyboxes | 🔴 Treyarch **BOCW** skybox HDRs on the stock t6 dome | the map's night sky (2026-07-02; was stock `skybox_default_night`). **Credit Nastian + Treyarch (BOCW) before Public** |
| WW2 power switch body (`ww2_circuit_breaker`) | Fanatic — WW2 Power Switch v1.0.1 | 🔴 Sledgehammer **CoD:WWII** circuit breaker, ported | the Bus Station power switch's visible body (model-only lift 2026-07-02; stock handle/logic kept). **Credit Fanatic + Sledgehammer (WWII) before Public** |
| Kino round-change stingers (round start/end, game over wavs) | Ultimate Round Sounds Pack (WetEgg; info MidgetBlaster; refs Booris, Peppergogo) | 🔴 Treyarch **WaW/BO1 (Kino/t5_theater)** audio rips | round-change stingers via `acc_round_sounds.csv` + `_acc_music.gsc` hooks (2026-07-02). **Credit WetEgg + Treyarch before Public** |
| Aetherium HUD (full stock-HUD replacement: 40 Lua widgets, 2 GSC/CSC modules, 2 TTF fonts, ~103 HUD images + compass material) | [Owen-C137's Aetherium-Hud-Bo7-Remake](https://github.com/Owen-C137/Aetherium-Hud-Bo7-Remake-) (Owen-C137; kit credits Kingslayer Kyle, Shidouri, MadGaz) | 🟡 **explicit licence: "free to use and modify … credit appreciated but not required"** — but the HUD *art* is BO7/CW-derived (theme plates, operator portraits, powerup icons), so the Treyarch-IP caveat still applies to the images | adopted 2026-07-03 as the map's base HUD (zone AETHERIUM block); Lua/GSC/fonts/strings vendored IN the repo (licence permits), images via the external pack (`model_export\_OwensAssets`). In-game author signatures disabled (`ShowSignatures=false` in AetheriumStartMenu.lua) — **credit Owen-C137 + Kingslayer Kyle + Shidouri + MadGaz + Treyarch here / on the Workshop page instead** |

> **Panzer / mechz** (Spiki) is *not shipped* in the `.ff` yet (WIP, `Required=$false`
> in `tools/external_assets_manifest.ps1`). Add a provenance row here **before** it
> first ships in a build — do not publish a build that packs it without one.

## IP review sign-off (the PUBLIC-release gate)

> **IP REVIEW STATUS: INCOMPLETE**
>
> `tools/prep_release.ps1` reads this exact marker. The map MUST stay **Private** on
> the Workshop until every box below is checked and this line is changed to
> **`IP REVIEW STATUS: COMPLETE`**. This is the [CLAUDE.md](CLAUDE.md) hard constraint
> ("never publish the Workshop item Public until the IP/credit review in CREDITS.md is
> done") made machine-checkable. Each box = confirm the asset's redistribution terms
> permit bundling in a free Steam Workshop map (author permission, or remove the asset),
> AND that the author + original studio are credited in the Workshop description.

- [ ] **Charred Zombie reskin** — Logical (+ Scobalula tools) permission confirmed; Logical + Treyarch credited.
- [ ] **Ronan perk-icon shaders** — Ronan permission confirmed; Ronan + Treyarch + Anna Kuźmińska + CD Projekt Red credited (pack readme: "Remember to credit").
- [ ] **Action Figure melee** — T0nic permission confirmed; T0nic + Treyarch (BO4) credited.
- [ ] **NSZ Brutus** — NateSmithZombies permission confirmed; NateSmithZombies + Treyarch (BO2) credited.
- [ ] **HB21 Civil Protector** — HarryBo21 permission confirmed; HarryBo21 + the pack credits list + Treyarch (BO3 SoE) credited.
- [ ] **Skye weapon ports** — TheSkyeLord + LilRobot permission confirmed; authors + original studios credited.
- [ ] **BOCW Cold War weapon ports (AK-47/AK-74u/M60/RPD)** — sourced from TheSkyeLord's CW pack since 2026-07-02 (author question resolved); TheSkyeLord + Treyarch (BOCW) credited (folds into the Skye permission item above).
- [ ] **West Electric Cherry machine** — Westchief596 permission confirmed; Westchief596 (+ machine-template authors Betiroval / F3ARxReaper666 / HarryBo21) + Treyarch (BO2) credited.
- [ ] **Blast-O-Matic** — Owens permission confirmed; Owens + `_mg` (camos) + Treyarch (BOCW/DOA) credited.
- [ ] **SAT Toxic boss skins** — WetEgg permission confirmed (readme asks for credit); WetEgg + Rayjiun + Treyarch credited.
- [ ] **BO1 Thundergun port** — TheAllNightFall permission confirmed; TheAllNightFall + Treyarch (BO1) credited.
- [ ] **ALXS CW/BO6 PaP machine** — ALXS permission confirmed; ALXS + Madgaz + Owen C137 + Treyarch (BOCW) credited.
- [ ] **Nastian T9 skyboxes** — Nastian permission confirmed; Nastian + Treyarch (BOCW) credited.
- [ ] **Fanatic WW2 power switch** — Fanatic permission confirmed; Fanatic + Sledgehammer (CoD:WWII) credited.
- [ ] **WetEgg round sounds (Kino)** — WetEgg permission confirmed; WetEgg + Treyarch (WaW/BO1) credited.
- [ ] **Aetherium HUD (Owen-C137)** — licence is explicit ("free to use and modify, credit appreciated") so no permission needed for the kit code, BUT the HUD *image* assets are BO7/CW-derived Treyarch rips — confirm the Treyarch-IP stance matches the other rip packs; Owen-C137 + Kingslayer Kyle + Shidouri + MadGaz + Treyarch credited on the Workshop page (in-game signatures are OFF); the two bundled TTF fonts' own licences (ltromatic, orbitron — Orbitron is SIL OFL, ltromatic UNVERIFIED) checked for redistribution.
- [ ] **L3akMod** — D3V Team credited (required by its licence; build-time tool, see Tools below).
- [ ] **`acc_main_theme` audio** — lnplusmusic "Suspense Dark Thriller Music" (Pixabay #392762) licence verified to permit Workshop redistribution, **or** swapped for a confirmed-CC0 track (see the ⚠️ row above).
- [ ] **`acc_ee_song` audio** — Lilex "Cyber Dreams" licence verified to permit Workshop redistribution, **or** swapped for a confirmed-CC0 track (see the ⚠️ row above).
- [ ] **`acc_ee_song_2` audio** — "the mountain" — "Cyber Security" (Pixabay #144111) licence verified to permit Workshop redistribution, **or** swapped for a confirmed-CC0 track (see the ⚠️ row above).
- [ ] 🚫 **`acc_ee_song_3` audio ("I Really Want to Stay at Your House")** — copyrighted (Rosa Walton / CD PROJEKT RED); **MUST be removed or swapped for a licensed/CC0 track before Public** (test-only, see the 🚫 row above).
- [ ] **`acc_brutus_music` audio** — alperomeresin "The Final Boss Battle" (Pixabay #158700) licence verified to permit Workshop redistribution, **or** swapped for a confirmed-CC0 track (see the ⚠️ row above).
- [ ] 🚫 **`acc_paradise_music` audio ("115")** — copyrighted (Treyarch/Kevin Sherwood); **MUST be removed or swapped for a licensed/CC0 track before Public** (test-only, see the 🚫 row above).
- [ ] 🚫 **`acc_paradise_calm` audio (Mario "Stage Win")** — copyrighted (Nintendo); **MUST be removed or swapped before Public** (test-only, see the 🚫 row above).
- [ ] **Workshop description** carries the full credits block (see [docs/55_release_runbook.md](docs/55_release_runbook.md)).

> If any asset's clearance cannot be obtained, the safe resolutions are (a) keep the
> item **Private**, or (b) **remove** that asset from the build before going Public.

## CC0 sources approved for future use (Phase 3)

When the bespoke HDRI sky / custom textures land (docs/29 §12.3), source from these
CC0 libraries (raw files may be bundled in a shipped game) and add a row above:

- **Poly Haven** — https://polyhaven.com/ (CC0) — night-city HDRI for the custom sky.
- **ambientCG** — https://ambientcg.com/ (CC0) — PBR walls/floors.
- **ShareTextures** — https://www.sharetextures.com/ (CC0) — PBR variety.
- **Kenney** — https://kenney.nl/ (CC0) — stylized decals / signage.

## Tools

- **L3akMod** (D3V Team) — required to build the custom LUI HUD. Credit in any
  release (see [docs/28_lui_pipeline.md](docs/28_lui_pipeline.md)).
