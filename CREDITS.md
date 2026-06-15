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
| `acc_main_theme` | `sound_assets/acc/music/main_theme.wav` | Joth — "Cyberpunk Moonlight Sonata" ([OpenGameArt](https://opengameart.org/content/cyberpunk-moonlight-sonata)) | CC0 | main theme; plays once at game start (stock ZM music disabled) |
| `acc_amb_city_bed` | `sound_assets/acc/amb/city_bed.wav` | Joth — "Ambience Pack 1: Sci-Fi Horror" (*Infestation in the Control Room*) ([OpenGameArt](https://opengameart.org/content/ambience-pack-1-sci-fi-horror)) | CC0 | global ambient bed (dvar `acc_amb_on`) |

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

> ⚠️ This ledger is **not yet complete**: the `.ff` also ships the 6 Skye weapon
> ports (TheSkyeLord + LilRobot) and NSZ Brutus (NateSmithZombies), and Panzer
> work is in progress — all game-rip, all owed provenance rows here before Public.

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
