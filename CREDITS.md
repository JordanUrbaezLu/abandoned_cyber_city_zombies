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

No third-party (non-stock) assets are shipped yet. All current atmosphere is
**stock + original**.

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
