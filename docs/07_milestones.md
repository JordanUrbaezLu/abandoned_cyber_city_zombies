# 07 - Milestones

Phased delivery history. This map was built solo, evenings/weekends, against the
phase graph below. **All v1.0-scope phases (0-6) are DONE** — the map reached its
**first clean compile + link on 2026-06-12** and has shipped systems, art, sound,
a full LUI HUD, bosses, and a release runbook since. This doc is now a **historical
record**: each phase lists what actually shipped and where the reality diverged from
the original plan. It is no longer a to-do list — the live tracker is
`15_requirements_checklist.md`, and current work is in `ROADMAP.md` / `CHANGELOG.md`.

Each phase kept **exit criteria** — objective tests you either pass or don't.

## Phase 0 - Research & Design Docs — DONE

**Goal.** Capture the design before we build.

**Shipped.** The `docs/` folder, `README.md` pitch, and `ROADMAP.md` phase graph.
The Cyberware tree, Data Shard economy, and randomization strategy were all
specced (`REQUIREMENTS.md`, `03_progression_and_skills.md`) before Phase 1.

## Phase 1 - Toolchain Install & Orientation — DONE

**Goal.** Build and run a hello-world map.

**Shipped.** BO3 Mod Tools installed on the Windows dev box (setup re-completed on
the new machine 2026-07-03 — see `SETUP_WINDOWS.md`). The edit -> build -> in-game
loop is the standing workflow: agents build headless via `tools/build_map.ps1`
(the Launcher GUI is not required), launch via `tools/run_game.ps1`.

## Phase 2 - Zombies Template + Greybox — DONE

**Goal.** A playable, mechanically-complete greybox of the zones in `02_layout.md`.

**Shipped.** The map source lives at `map_source/zm/zm_abandoned_cyber_city.map`
(Radiant sources live under `<BO3 root>\map_source\zm\`, **not** under `usermaps/`),
the zone manifest at `zone_source/*.zone`, and the entry scripts at
`scripts/zm/zm_abandoned_cyber_city.gsc|.csc` (BO3 puts them in `scripts/zm/`, not
`maps/zm/`). All surface zones, buyable doors (`script_flag enter_*`), inline mystery
boxes, power switches, perk-machine slots, and PaP landed. The layout later grew a
vertical **"Abyss Descent"** underground (soul-box layers L2/L3/L5 down to the
Paradise plaza — `_acc_abyss_doors.gsc`, `_acc_bus_trench.gsc`), which replaced the
originally-sketched flat "Black Market" split-room design (never built).

**Exit criteria (met).** Reach round 10 with Box + PaP, all zones accessible, no
script errors across a full playtest. The greybox superset shipped as the real map.

## Phase 3 - Core Custom Systems (Data Shards + Cyberware + Overclocks) — DONE

**Goal.** The mechanical core works.

**Shipped** (all wired in `_acc_main.gsc::init()`):
- `_acc_data_shards.gsc` — Data Shard currency + elite-kill drops. (The HUD counter
  is **not** a placeholder `iprintln` — it renders in the full Aetherium **LUI** HUD;
  see Phase 4.)
- `_acc_cyberware.gsc` — the Cyberware node graph from `03_progression_and_skills.md`.
  **Disabled in play since 2026-06-19** (`_acc_cyberware.gsc:92-96`): the kiosk only
  spawns behind `acc_cyberware_on 1` (default `0`), so no node is buyable and the tree
  is inert. The weapon **Overclock Terminal** (below) is now the sole live upgrade path.
  The module stays loaded — its damage-flag readers are harmless no-ops with nothing
  bought — and the full tree can be re-enabled with `acc_cyberware_on 1` (also noted in
  `03_progression_and_skills.md`).
- `_acc_overclocks.gsc` — weapon-family registry + per-run active-pool roll, applied
  at the Lab Overclock Terminal (the live weapon-upgrade path).
- `_acc_map_randomizer.gsc` — power side, PaP approach, wallbuy/perk pools all re-roll
  on map load.
- `_acc_elites.gsc` — elite classes dropping Shards.
- `_acc_emergency_drop.gsc` — power-switch-callable drop.

All currency writes are per-player and multiplayer-safe.

## Phase 4 - Remaining Systems + Custom UI + Content Pass — DONE

**Goal.** Feature-complete map. All mechanics, all content, real UI.

**Shipped:**
- **Bosses** — a full roster, not placeholders: Brutus (`_acc_boss_brutus.gsc`),
  Glitch (`_acc_boss_glitch.gsc`), Phantom (`_acc_boss_phantom.gsc`), Avogadro
  (`_acc_boss_avogadro.gsc`), Panzer/mechz, plus the Rogue/Civil Protector r20 boss,
  shared via `level.acc_boss_roster_fn`. Cadence: the **Trench Warden mini-boss debuts
  once power is on AND round >= 5** (`acc_warden_first_round`, default 5), then respawns
  3 rounds after each kill (kill-anchored, not a fixed round);
  full **boss rounds every 9 from round 9** (r9=1, r18=2, r27=3), with types dealt
  from a no-duplicate shuffled deck (see `_acc_boss.gsc`). *(The old "one boss every
  10" plan is superseded.)*
- **Events** — `_acc_events_hack.gsc` (Hack Terminal, live at `_acc_main.gsc:198`).
  **`_acc_events_overload.gsc` (Vault Overload) is RETIRED** — commented out at
  `_acc_main.gsc:199`, its `.map` trigger/point struct removed; the `#using` is kept
  only for easy restore.
- **Perks** — **10 perks** (`10_perks.md`), including the finished **Electric Cherry**
  pipeline (`_acc_perk_electric_cherry`, called directly from the entry script) as the
  real 10th perk. Slot cap `ACC_PERK_SLOT_MAX = 10` with escalating shard costs
  (4/6/8/10/12/14); perk availability is the map-wide scatter (`_acc_perk_scatter.gsc`,
  replaced the Lab-alcove 4-of-10 door roll 2026-07-24). Base perks are
  retuned in `_acc_perks.gsc`; the no-perk-cap override is hooked.
- **Wonder weapon** — settled, not "one of three, TBD": the **Havoc charge** wonder
  weapon (`_acc_havoc_charge.gsc`, init at `_acc_main.gsc:249`). The arsenal also
  includes adopted-pack guns (Apex + Skye ports) and the HB21 elemental bows.
- **UI** — the full **Aetherium LUI HUD** is the shipped base (since 2026-07-03):
  `scripts/zm/_zm_aetherium_hud.gsc|.csc` driving `ui/uieditor/menus/hud/*.lua` via
  clientfields. Round progress is a smooth **bar** (the radial ring was abandoned); a
  gun-badge chip row shipped 2026-07-08. *(The Phase-3 "LUI deferred, iprintln OK"
  staging is obsolete.)*
- **Modifiers** — `_acc_modifiers.gsc` defines **11**, not "at least 4":
  `code_red`, `limited_liability`, `fragility`, `bleed_out`, `draft_mode`,
  `shardless`, `one_shot`, `roguelike_lite`, `express`, `sprint`, `shortened_rounds`
  (`_acc_modifiers.gsc:62-72`).

**Beyond the original Phase-4 scope**, these systems also shipped: Exo Suit station
(`_acc_exo.gsc`), Armory upper room (`_acc_armory.gsc`), Reactor Surge
(`_acc_reactor.gsc`), Glitch Altar (`_acc_glitch_altar.gsc`), Jukebox
(`_acc_jukebox.gsc`, which replaced the EE-song teddy bears), and The Exchange
transfer vault (`_acc_transfer.gsc`). In total ~61 `_acc_*.gsc` modules exist on disk;
~48 are active in `_acc_main.gsc::init()`.

## Phase 5 - Art Pass (minimal) — DONE

**Per user direction: art is legibility, not a showcase.**

**Shipped.** Stock-asset cyber/industrial reskins (a brush face's material token *is*
the GDT material name — re-skin = swap the token; see `BO3_MAPMAKING_KB.md` / the
atmosphere notes in CLAUDE.md), per-zone lighting, stock ambient sound aliases, and a
ZM-safe night skybox. The map **bakes** again after the pre-stage3 revert (~157 light
entities + ~15 reflection probes); `tools/build_map.ps1` runs the LED bake **by
default** — `-SkipLED` is a red flag, not the norm. Later remodels swap greybox for
stock props carved from the T7 assets dump (`09_boss_items.md`).

## Phase 6 - Playtest, Tune, Polish — ONGOING

**Goal.** Feels good; balance is close; bugs are low.

This is the standing state of the map: iterative playtests feed a continuous balance +
bug-fix loop (see `CHANGELOG.md` — HP tuning, economy/HUD sync, zombie speed curve,
coop-crash hardening). Balance levers in play: Data Shard drop rates, Overclock upgrade
strength, elite/boss HP and spawn timing, and wallbuy/perk/Overclock pool weights.
(Cyberware capstone tuning is dormant along with the disabled tree — see Phase 3.)

## Phase 7 - Release — PENDING

**Goal.** Public on Steam Workshop.

The release pipeline is built and documented (`34_release_runbook.md`,
`34_release_runbook.md`), but the Workshop item **must not go Public until the
IP/credit review in `CREDITS.md` is complete** (external game-rip asset packs are not
redistributable). Remaining: Workshop page copy + screenshots, v1.0 git tag, and a
fresh-install run by a non-dev tester.

## Post-1.0 (tracked for future)

- Seeded runs (paste a seed, reproduce a map state).
- A true main Easter Egg, if player feedback demands it (explicitly deferred per design
  direction — not promised).
- Traps.
- Leaderboard integration if any community solution exists.
