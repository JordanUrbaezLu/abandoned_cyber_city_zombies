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
| Skye weapon ports (Tac-19, Five-Seven, ASM1, AE4, Galil, Olympia, Chicom, PPSH, MK14, MORS, RW1, Ripper, + FAL) | Skye's Weapon Ports to BO3 (TheSkyeLord + LilRobot) | 🔴 Treyarch / Sledgehammer **BO2/BO3/AW/VG** weapon models + anims, ported to BO3 | box + wall-buy guns; pack gitignored (marker `model_export\skye_ports`). **Credit TheSkyeLord + LilRobot + the original studios before Public** |
| BOCW Cold War weapon ports (`t9_ak47` AK-47, `t9_ak74u` AK-74u, `t9_m60` M60, `t9_rpd` RPD) | BOCW→BO3 community port (**author TBD — IDENTIFY before Public**) | 🔴 Treyarch **BOCW (Cold War, `t9`)** weapon models + anims, ported to BO3 | box guns — newer models swapped 2026-06-25/26 onto the BO1/BO2 originals' grafted stats; pack gitignored (marker `model_export\t9_wpn_ports`). **Identify + credit the port author + Treyarch (BOCW) before Public** |

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
- [ ] **Skye weapon ports** — TheSkyeLord + LilRobot permission confirmed; authors + original studios credited.
- [ ] **BOCW Cold War weapon ports (AK-47/AK-74u/M60/RPD)** — port author identified + permission confirmed; author + Treyarch (BOCW) credited.
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
