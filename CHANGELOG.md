# Changelog

All substantive design + implementation changes. Follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) structure loosely. Dates are when the change was decided / committed, not shipped.

Version scheme: `v0.x.y` during pre-release (no public v1.0 yet). `v1.0.0` = first Workshop publish.

## [Unreleased]

### Fixed — first compile, pass 6: field access on a parenthesized expression (2026-06-12)

`_acc_damage.gsc:661` had `return ( zm_weapons::get_base_weapon( w ) ).name;`
→ `Compiler Internal Error: Primitive expression field object must be either
call, variable expression, self, level, or anim`. GSC forbids `.field` on a
**parenthesized** expression. (A direct `call().field` IS allowed — stock uses
`GetPlayers().size` 15 times — so the two such calls in `_acc_coop_scaling` are
fine; only the paren-wrapped one breaks.) Fixed with a temp:
`w_base = zm_weapons::get_base_weapon( w ); return w_base.name;`.

`tools/lint_gsc_xref.js` gained two checks: a paren-aware `( expr ).field`
detector (matches the `(` back, flags grouping parens, ignores function-call
parens), and **function-pointer resolution** — `&ns::fn` and bare `&fn` (used
in `register_*` callbacks) are checked the same as calls, since a typo'd
pointer is also an unresolved external. Swept clean: the only pointer is
`&zombie_utility::default_max_zombie_func` (confirmed in the mirror).

### Fixed — first compile, pass 5: proactive cross-reference sweep (2026-06-12)

The compile reached `_acc_boss.gsc:551` with `Unresolved external
'acc_coop_scaling::special_hp_mult'` — `_acc_boss.gsc` called that function but
never `#using`'d `_acc_coop_scaling` (an earlier node-patch added the calls but
its `#using` insertion silently failed to match). Added the missing `#using`.

Rather than rebuild-per-error, swept the **whole codebase** for this class and
its siblings with a new tool, `tools/lint_gsc_xref.js` — found **only this one**
real issue. The checks (all reliable, run in preflight now):
- every `acc_X::fn()` call has a `#using _acc_X` and `fn` is defined there;
- every stock `ns::fn()` call has the right stock `#using` (hardcoded verified
  namespace→file map — `util`→`util_shared`, `flag`→`flag_shared`, etc.);
- every stock macro (`IS_TRUE`, `PERK_*`, `VERSION_SHIP`...) has its `#insert`
  (transitive `.gsh` resolution from the mirror);
- no bare `fn()` call resolves to a different acc module (missing namespace).
- Also confirmed all 21 flagged stock functions exist in the mirror (so the
  "BAD STOCK API" noise was indexer false positives, not real) — the lint
  deliberately does NOT check stock-function existence (unreliable; compiler's
  job).

Progress: 12 modules + the entry script now compile clean (cyberware,
data_shards, early_round_pacing, elites, emergency_drop, events_hack,
events_overload, main, map_randomizer, modifiers, overclocks, utility). The
remaining untested modules (boss, boss_items, mega_bottles, weapon_abilities,
points, damage, decontamination, coop_scaling, perk_aura_blast) passed all four
dependency lints, so any further error is a different class.

### Fixed — first compile, pass 4: `class` reserved keyword as a variable (2026-06-12)

GSC compile reached `_acc_elites.gsc:147` (`spawn_elites_over_round`) and
rejected `class = pick_elite_class_for_round(...)` — `class` is a reserved
keyword (TOKEN_CLASS) in BO3 GSC and can't be an identifier. Renamed to
`elite_class`. Swept the codebase for reserved words as identifiers (lvalue /
param / foreach): only this one was real. `type` flagged as a false positive —
stock uses it as a parameter (`setup_hero_rival(... type)`), so it's NOT
reserved and was left alone.

Hardening: `preflight_windows.ps1` now lints a narrow confirmed reserved-word
list (`class`) used as identifiers — kept narrow to avoid false positives.

Progress: the `.gsc.gdb` outputs show utility, main, data_shards, cyberware,
overclocks, early_round_pacing all compiled clean this pass before the elites
break — the phase-2 body compile is steadily clearing modules.

### Fixed — first compile, pass 3: GSC ternary paren-wrapping (2026-06-12)

Past the directive fix, the GSC compile reached `_acc_data_shards.gsc:185`
and rejected an unwrapped ternary: `= ( self.acc_data_shards > 0 ) ? 0.9 : 0`
(`unexpected TOKEN_CONDITIONAL, expecting TOKEN_SEMICOLON`). BO3 GSC has no
general ternary operator — it only parses a **fully paren-wrapped**
`( cond ? a : b )` (verified vs stock: `util_shared.gsc:1425`,
`:3990`, `:3996` all wrap the whole expression). Our broken sites either
closed the paren after the condition (`( cond ) ? a : b`) or were bare
(`return cond ? a : b`).

Swept **every `?` in the codebase** (the first pass's grep wrongly excluded
`::`-containing lines, hiding two `return acc_utility::...( ) == 0 ? a : b`
sites) and fixed all **9 broken ternaries** to `( cond ? a : b )` across
`_acc_boss` (2), `_acc_data_shards` (1), `_acc_mega_bottles` (1), and
`_acc_map_randomizer` (5). The 3 already-wrapped ones were left alone.
`?`-in-string-literal log messages are not ternaries (left alone).

Hardening: `preflight_windows.ps1` gained a **paren-aware ternary lint** (walk
each line at paren depth; a `?` at depth 0 is unwrapped) — catches this class
with zero false positives, unlike a regex. Would have flagged all 9 pre-build.

### Fixed — first compile, pass 2: GSC directive-ordering error (2026-06-12)

With the skybox fixed, the build reached the **GSC compile** (geometry +
Umbra + lighting all passed) and hit one syntax error:
`_acc_boss_items.gsc (15,6): syntax error, unexpected TOKEN_USING, expecting
$end`. Cause: `#namespace acc_boss_items;` was on line 13, **above** the
`#using` block — `#namespace` terminates the directive preamble, so the
following `#using` lines are illegal. Fixed by moving `#namespace` below all
`#using`/`#define`. Scanned all 21 modules: only this one had the bug; the
other 20 order `#namespace` correctly.

Signal from the compiler: it processes `_acc_main`'s `#using` list in order
and stopped on the 12th dependency, so the **11 modules before it compiled
clean** (utility, data_shards, cyberware, overclocks, elites, map_randomizer,
events_hack, events_overload, emergency_drop, modifiers, boss). The remaining
modules (mega_bottles, weapon_abilities, points, damage, early_round_pacing,
decontamination, coop_scaling, perk_aura_blast) get their first compile on the
next build.

Hardening: `tools/preflight_windows.ps1` now lints GSC directive ordering
(`#namespace` after every `#using`/`#insert`/`#define`/`#precache`) across all
modules — the brace/paren lint missed this class. Also verified all `_acc_`
`#using` paths resolve to real files and no module self-imports.

### Fixed — first compile, pass 1: MP-skybox link error + chalk-material warnings (2026-06-12)

The first real Launcher build reached the linker and died on ONE hard error
(`^1ERROR: xmodel 'skybox_mp_havoc_override' is missing`, referenced by the
gfx_map). Root cause: the stock zm-template `volume_sun` entity ships with
**MP sky settings** — `ssi1`/`ssi2` = `mp_havoc`, `ssi1_runtime_override` =
`mp_havoc_overide` — and the `mp_havoc` sun/sky asset pulls in
`skybox_mp_havoc_override`, an **MP-only skybox** that does not exist in a ZM
build. Fixed by setting all three to `default_day` (matching the worldspawn
`ssi`/`wsi` and the sun volume's primary `ssi`, which converted cleanly). The
power-on lighting-state switch (`util::set_lighting_state`) now stays on
`default_day` for every state — cosmetically the lighting no longer changes
mood on power-on, which is correct for greybox (and avoids the MP dependency).

Also cleared the two non-fatal chalk-material warnings
(`t7_zm_chalk_buy_icr1`, `t7_zm_chalk_buy_drakon`): the stock asset set has
**no ICR-1 or sniper chalk decals at all** (verified against the installed
asset list — only arak/bowie/cqw/frag/krm/kuda/m8a4/shiva/spyder/trip_mine/
triton/vmp exist). Repointed both to `t7_zm_chalk_buy_shiva` (a confirmed-
converting AR chalk) as a greybox placeholder; real imported guns bring their
own chalk later.

**Note for the next build**: the link died at a gfx_map (geometry) asset
*before* the linker reached the `scriptparsetree` GSC compilation, so the 21
`_acc_` modules have **not yet been compiled** — the next build is the first
real test of the GSC. Findings logged here as we go (standing convention:
first-compile discoveries get documented).

### Added — Windows build-readiness: preflight automation, sync fixes, Mod Tools live (2026-06-12)

- **The machine is build-ready: `tools/preflight_windows.ps1` reports ALL 20
  CHECKS GREEN** — repo integrity (map brace balance, zone↔module
  consistency), line endings, execution policy, disk/RAM, the officially
  documented Windows locale requirement (decimal symbol "."), BO3 + Mod Tools
  installs, extracted prefabs, and the synced usermap. Run it any time;
  failures print the exact fix.
- **Mod Tools detected at the AppID-suffixed folder**
  `...\Call of Duty Black Ops III 455130` (Steam name-collision layout).
  Both `sync_to_modtools.ps1` and the preflight now identify the tools root
  by `bin\modlauncher.exe` — the old folder-name detection would have synced
  into the GAME folder and the Launcher would never have seen the map.
- **Fixed a latent parse bug in `sync_to_modtools.ps1`** (`"$label:"` is a
  drive-qualified variable reference in PowerShell — the script had never
  been executed on a real Windows box). **First real sync completed**: all
  trees + the .map are in the usermap / tools `map_source`.
- **`.gitattributes` added** (`* text=auto eol=lf`): line-ending policy is
  now repo-pinned and machine-independent; Radiant's CRLF re-saves normalize
  back to LF on commit. Verified zero-churn (everything already LF).
- **[SETUP_WINDOWS.md](SETUP_WINDOWS.md) rewritten** for reality: this
  machine's verified state up top, install facts corrected against the
  open-sourced Treyarch Launcher + official guides (Mod Tools = ~25 GB base
  **+ the ~50 GB "Additional Assets" DLC** — a step the old doc omitted
  entirely; the big one-time extraction is **Radiant's first launch**, not
  the Launcher's; Launcher lists any usermap with a `zone_source/*.zone` —
  "New Map" never required, verified in Launcher source; run-options box +
  Edit→Dvars are both valid for `+set developer 1`), the evidence-backed
  top-5 first-build failures, the full in-game test loop (doors → perks →
  decon → `acc_test_boss` Mega loop), and the post-first-build priority list.
  CLAUDE.md hard constraints updated (compiles now possible via Launcher).

### Added — community techniques ledger + research knowledge base (2026-06-12)

- **[docs/22_community_techniques.md](docs/22_community_techniques.md)** —
  **142 techniques across 18 systems** mined from shipped community sources by
  a 7-agent fleet reading actual code line-by-line (elevator/transport
  choreography, endgame flow, LUI menu + HUD pipelines, custom perk kits, soul
  boxes, traps + zombie POI lure, item-drop frameworks, quest chains, sound
  states, performance budgets, publishing anatomy...). Every entry = exact
  mechanism + repo/file/line citation + how our map uses it. **Standing
  convention** (also saved to session memory): every external-codebase finding
  gets documented here; raw dossiers go to **[docs/research/](docs/research/)**
  (the 9 stock/shipped ground-truth dossiers + weapon research are now
  committed there — they're the receipts behind the `VERIFIED(acc)` code
  comments).
- **14 newly discovered verified source repos** catalogued (headliners:
  `kelson8/bo3-Zombies-Test-Map` — a working GSC→LUI purchase-menu bridge,
  the blueprint for our Cyberware tree UI; `Scobalula/Bo3CWStyleItemDrops` —
  weighted item-drop framework for physical Data Shard pickups;
  `Owen-C137` Aetherium HUD (clientfield→LUI pipeline, bit-packed state) +
  sawblade trap kit; `Resxt/T7-Scripts` soul boxes/challenges/buyable ending;
  `shidouri/T7-GDT-Backup` — greppable stock GDTs, the asset-layer ground
  truth we lacked). CLAUDE.md ground-truth section updated.
- **First technique applied immediately**: `level.perk_purchase_limit = 9` in
  the entry script — the writable stock field for the perk cap
  (`_zm_perks.gsc:43`, shipped precedent in two maps) closes the
  **no-perk-cap requirement** that was waiting on a planned `_acc_perks.gsc`
  override. Checklist: 202/471.

### Added — full requirements push: doors+boxes+terminals, decontamination, co-op scaling, effect consumers, visual map design (2026-06-12, second ultracode pass)

9-agent file-owned implementation fleet + map pass 3 + integration. Tracker
now at **201/471 implemented** ([docs/20_requirements_checklist.md](docs/20_requirements_checklist.md));
everything still open is categorized with reasons + unblock steps in
**[MISSING_REQUIREMENTS.md](MISSING_REQUIREMENTS.md)**.

- **Visual map design**: [docs/map_design.svg](docs/map_design.svg) (+ .png) —
  rendered from the LIVE .map by `tools/gen_map_design.js` (parses the entity
  lump): all 7 zones, 8 corridors, every perk/wallbuy/box/door/terminal/
  power/spawn marked with legend. Linked from docs/03.
- **Map pass 3** (`tools/gen_interactives.js`, one-shot): 8 buyable doors
  (trigger_use + sliding script_brushmodel slab per corridor, costs
  750/1000/1250/1500, script_flag `enter_*`; zone adjacency flags switched
  from always_on to the door flags — zones now open by purchase); 3 inline
  Mystery Boxes replacing the single template box (zbarrier_zmcore_MagicBox +
  treasure_chest_use struct pairs with `acc_box_market/corp/roof` noteworthy
  pairing, KVPs verbatim from the shipped box_start.map — the randomizer's
  initial-box roll is now live); 2nd power switch (Vault) with
  `script_string` side tags; acc_cyberware_kiosk + acc_overclock_terminal
  (Lab), acc_hack_terminal (Corp), acc_overload_terminal + point (Vault),
  acc_power_corp/vault emergency-drop triggers, acc_pap_block_server/roof
  brushes (both Lab corridors), acc_boss_spawn struct (Lab).
- **NEW `_acc_decontamination.gsc`**: docs/03 hazard complete — per-run
  permutation of the 4 eligible zones, rounds 1-4 contaminate one each
  (20s evac warning + countdown, stragglers die via the stock kill path),
  permanent seal (spawning disabled + kill-on-reentry monitor), emits
  acc_decontamination_start/complete; **Lab perk rotation now keys on
  acc_decontamination_complete** (the docs-mandated timing), every round.
- **NEW `_acc_coop_scaling.gsc`**: regular zombie HP +100%/player (delta vs
  stock's own scaling, via the level.zombie_init_done hook), elites/bosses
  +50%/player (`special_hp_mult()` consumed by elites + both boss spawns),
  spawn rate +30%/player (max_zombie_func chained after early pacing).
- **`_acc_damage.gsc`** is now the single consumer of every damage-side
  contract flag: Cyberware Amplifier ×1.15 + Overload crit chain, Kinetic
  Battery 3× discharge (accrual added in `_acc_points` — 10 kills),
  Precision Mode (3 auto-crit ×4) + Slug Round (×3) ability flags, the
  damage-shaped Overclocks (Overpressure ADS ×1.5, Piercing/Penetration/
  Breach shield-bypass, Reactive Powder headshot AoE, Adaptive Aim refund),
  Shielded-elite frontal ×0.25 resist with pierce/explosive counter-play.
- **`_acc_cyberware.gsc`**: all 9 node effects real — Phase Step (slide →
  160u blink through zombies, walls block, 6s CD), Ghost Protocol (2s
  still → stock ignoreme cloak), Meltdown (no-chain corpse AoE with kill
  attribution), Caching (2× bleed-out via the stock laststand multiplier
  field), plus crouch+use respec at the kiosk (3-Shard tax, once/run,
  never T3).
- **`_acc_boss.gsc`**: mini-boss rounds now REPLACE the wave
  (level.zombie_total=0 at boss round start); full boss Subroutine Core is a
  real damageable actor spawned at acc_boss_spawn (stationary, failsafe+
  enemy-count exempt — boss rounds 30+ run normal waves alongside);
  acc_boss_dead carries killer payload; co-op HP scaling applied.
- **`_acc_events_hack.gsc` / `_acc_events_overload.gsc`**: both events
  completable end-to-end against the placed terminals (3-stage hack,
  90s overload defense at the point struct), kill counting via the verified
  death-event callback, sr2a retry honored, shortcut reward no-ops with a
  log until its geometry exists (design call — see MISSING_REQUIREMENTS).
- **`_acc_elites.gsc`**: per-round shard-diminish counter reset, co-op HP,
  quota table verified vs docs/11; **`_acc_map_randomizer.gsc`**: all three
  TODO applies real (dead power switch DELETED pre-tick by side tag; PaP
  blocker hidden/connected on the open side; wallbuy pool rewrites the
  post-init purchase layer — struct rewrite is provably unsafe client-side);
  **`_acc_weapon_abilities.gsc`**: Precision/Slug/Whirlwind real, weapon
  table fixed to verified class names, GDT-bound abilities honestly stubbed.
- 22 items confirmed unresolvable from this machine — all documented with
  what's needed in MISSING_REQUIREMENTS.md (headline: everything is
  compile-unverified until Mod Tools exist on a Windows box; imports need
  the Skye packs downloaded; recoil/fire-rate/LUI effects need Phase 4
  GDT/csc work).

### Fixed — adversarial verification pass over the zones+mega+boss commit (2026-06-12)

15-agent verify pass (one adversarial reviewer per changed file/aspect +
independent refutation judges; zero findings refuted). All confirmed defects
fixed in the same day:

- **Sky hull sealed off the Lab** (the big one): the template skybox's north
  wall sat at y≈2900 — the Lab, both Lab corridors, and the north 500u of
  Vault/Roof were OUTSIDE the sealed hull, making all 9 perk machines, PaP,
  and Bowie permanently unreachable (and zombies spawning at the northern
  risers unable to path). Extended the hull (north wall + floor/ceiling/east/
  west sky brushes to y=4300) and the sun + umbra volumes to match.
- **Cherry hijack hole #1**: the stock cherry module also wires
  `level.custom_laststand_func` — downing with Aura Blast fired Electric
  Cherry's laststand AOE (DoDamage + STOCK points bypassing our economy).
  Replaced with a visionset-only stub (`_zm.gsc` skips the standard laststand
  visionset for cherry-perk holders, so the stub re-applies it).
- **Cherry hijack hole #2**: cherry's machine-setup KVPs are a Treyarch
  placeholder naming the machine `vending_marathon` — Stamin-Up's think loop
  captured our Aura Blast machine (reskinning it as Stamin-Up) while cherry's
  own think scanned `vending_electriccherry` and found nothing. Fixed by
  renaming the spawned machine/trigger at init and bouncing both
  `perk_machine_think` loops (PERK_END_POWER_THREAD endon).
- **Boss soft-lock combo**: the host was counted toward round end AND opted
  out of the stuck-zombie failsafe — a pathing-stuck boss = round never ends.
  Removed the failsafe opt-out (boss death is the reward trigger; a stuck
  boss now self-cleans); header comment corrected (boss is ADDITIVE to the
  wave — replacement still open in the checklist). Also switched to the stock
  `set_zombie_run_cycle("run")` setter and made `acc_test_boss` re-sampled
  every round so the console toggle works mid-match.
- **Move-speed last-writer-wins bug**: Flash's read-modify-write ×1.12 was
  silently erased by Neural Boots / Reflex T1 absolute writes (and its
  removal could push speed below baseline). Centralized: ONE recompute
  (`acc_utility::recompute_move_speed`) owns `SetMoveSpeedScale`; boots /
  rx1 / Flash all set flags and call it.
- **HUD counters anchored mid-screen**: `setPoint("BOTTOMLEFT")` is not a
  recognized token (stock only matches "BOTTOM_LEFT"/"BOTTOM LEFT") — both
  counters silently rendered near screen center. Fixed both.
- **Minigun powerup short-circuited our damage callback** (registered first,
  returns non-−1 for every minigun hit): headshot multipliers + 70/30
  contribution were skipped for minigun fire. Our callback now runs first
  and passes minigun hits through (recording the contribution) so stock
  minigun balancing still applies; the wrong ordering comment fixed.
- **Map data fixes**: 3 dog_location structs were inside obstacle brushes
  (market stall / corp fountain / roof obstacle — dogs would teleport into
  solid and stall dog rounds); frag wallbuy model struct 0.5u inside the
  vault wall; 3u zone-volume coverage gap in the spawn↔market doorway.
  Aura Blast also got: chord-drain (holding crouch+melee can't auto-dump the
  Mega second charge) and Widow's-Wine-web coordination on the shared
  ASMSetAnimationRate.

### Added — 7-zone greybox + Mega upgrades + real mini-boss + requirements tracker (2026-06-12, ultracode pass)

Backed by a 39-agent audit (471 requirements extracted and statused vs the
real code+map) + 9 stock/shipped ground-truth dossiers + a 27-agent weapon
import research pass (23/23 sources URL-verified). New tracker:
**[docs/20_requirements_checklist.md](docs/20_requirements_checklist.md)** —
work top-down from it.

- **7-zone greybox map** — the whole docs/03 zone graph is in the .map:
  market/alley/corp/vault/roof/lab rooms + 8 corridors (exactly the 8 graph
  edges; no Spawn↔Corp or Corp↔Lab shortcut), per-zone `info_volume`
  (player_volume, target `<zone>_spawners`) + 4 risers + 1 dog struct each,
  training geometry (spawn debris loop, market stall row, corp fountain +
  S-curve, roof central obstacle), spawn-perimeter corridor cuts. Generated
  deterministically by `tools/gen_zone_greybox.js` + applied by
  `tools/apply_zone_greybox.js` (one-shot scripts, refuse to double-apply).
  Gameplay set relocated to doc zones (`tools/apply_entity_moves.js`): all 9
  perk machines + PaP + Bowie → Lab; ICR-1 + Sheiva wallbuys + power switch →
  Corp; Haymaker → Alley; Drakon → Roof; Frag → Vault; Mystery Box → Market.
  Chalk decals moved with their wallbuys.
- **Zone manager wired** — entry script `usermap_test_zone_init` now makes 8
  `zm_zonemgr::add_adjacent_zone` calls on the always-set `"always_on"` flag
  (VERIFIED: an info_volume alone does nothing — zones only exist once
  zone_init runs via adjacency/init list, `_zm_zonemgr.gsc:288/:595`; the
  shipped `zm_alien_isolation` works exactly this way). Buyable doors arrive
  next pass (swap flags to door `script_flag` "enter_*" KVPs).
- **Mega Bottle upgrades are live end-to-end** — `_acc_mega_bottles.gsc`:
  - Machine interaction: parallel `trigger_radius_use` spawned at every
    `zombie_vending` trigger with INVERTED per-player visibility (VERIFIED:
    perk owners can never fire the stock trigger — `check_player_has_perk`
    SetInvisibleToPlayer's them every 0.1s, `_zm_perks.gsc:865`), shown only
    to players who own the base perk + hold a bottle + aren't Mega'd.
  - Real Mega effects: **Ultimate Tank** (+100 max HP via
    `n_player_health_boost` — the only field stock's health_reboot recompute
    preserves across revives, `_zm_perks.gsc:828`), **The Flash** (+12% move,
    multiplicative compose, re-applied on respawn — stock resets the scale,
    `zm_usermap.gsc:336`), **American Sniper** (×1.75 headshot replacing
    Deadshot's new base ×1.5, in `_acc_damage`), **Spiderman** (melee OHK on
    ordinary zombies, in `_acc_damage`), **Mega Man** (800u / 60s / 2
    charges / reduced boss stun, live-read in `_acc_perk_aura_blast`).
    Gun Slinger / Savior / Sleight Expert / Armory: flag set, effects
    TODO(acc-mega) (need engine-side hooks).
  - Sticky persistence via stock lifecycle pointers `level.perk_bought_func`
    / `level.perk_lost_func` (re-buy re-applies; Jug boost cleared on loss).
  - Display-name keys fixed to the REAL specialties (`specialty_deadshot`,
    `specialty_widowswine`, `specialty_electriccherry` — the old
    `specialty_acc_*` keys could never match).
- **Deadshot base effect implemented** — ×1.5 headshot for the shooter when
  `HasPerk(specialty_deadshot)` (docs/13), stacking with the 2×/3× map
  multiplier in `_acc_damage::on_ai_damage`.
- **Real Juggernaut Host mini-boss** — `spawn_juggernaut_host` is no longer a
  stub: spawns via `zombie_utility::spawn_zombie` + the verified
  init-flag-poll pattern, 50k HP (docs/11), mechz-mirrored durability set
  (`no_gib`/`ignore_nuke`/`ignore_round_spawn_failsafe`/...),
  `acc_is_mini_boss` for the 3× headshot rule, death watcher drops boss item
  (50%) + **1 Mega Bottle per player**. r10=1 / r20=2 scheduling already
  existed. **Test loop: `acc_test_boss 1` dvar** spawns a killable 1500 HP
  host every round from round 2 — the Mega loop is testable immediately.
- **Fixed two latent map-load crashes** — `_acc_data_shards` and
  `_acc_mega_bottles` registered `"toplayer"` clientfields GSC-only;
  VERIFIED vs the whole stock mirror: every toplayer field is registered in
  BOTH VMs (zero counterexamples), mismatch = load failure. Replaced with
  classic server-side hudelems (`hud::createFontString` + numeric `SetValue`,
  no localization, no .csc) — shards counter + bottle counter now actually
  render. LUI clientfield bridge returns in Phase 4 via the safe
  `clientuimodel` pool.
- **[docs/21_weapon_import_sources.md](docs/21_weapon_import_sources.md)** —
  all 7 roster imports resolved to TheSkyeLord's verified packs (B23R=`t6_b23r`,
  Tac-19=`s1_tac19`, AK-47, M14 EBR=`iw4_m14ebr`, G3, FAL, Intervention=
  `iw4_intervention`) + install recipe. Two doc corrections flagged: B23R is
  BO2 (not "MW series"), G3 is CoD4/MWR (WaW has the Gewehr 43).

### Added — start-room gameplay set: all 9 perks + 6 wallbuys in one big room (2026-06-11)

Everything currently placeable now lives in the (enlarged) start room in
**[map_source/zm/zm_abandoned_cyber_city.map](map_source/zm/zm_abandoned_cyber_city.map)**,
so all systems can be developed/tested against real machines before Phase 2
splits the map into zones (greybox placement — final layout per
docs/03_layout.md and docs/13_perks.md):

- **Deadshot Daiquiri machine** — inline `script_struct` (`targetname
  "zm_perk_machine"`, `script_noteworthy "specialty_deadshot"`, model
  `p7_zm_vending_ads`, `script_string "zclassic_perks_start_room"`), placed in
  the perk row east of Mule Kick. Format proven by shipped `zm_alien_isolation`
  (ships jug as the same inline struct, no prefab needed) + stock
  `_zm_perk_deadshot.gsh` defines (machine model/name). The entry script
  already `#using`s `_zm_perk_deadshot` and precaches `ZOMBIE_PERK_DEADSHOT`,
  so no script change was needed. Location match verified:
  `zm_usermap.gsc:122` sets `default_start_location = "start_room"` →
  `perk_machine_spawn_init` match string `"zclassic_perks_start_room"`.
- **Widow's Wine machine** — same inline-struct pattern on the new south
  wall (`script_noteworthy "specialty_widowswine"`, model
  `p7_zm_vending_widows_wine`, per stock `_zm_perk_widows_wine.gsh`).
- **Aura Blast machine + module — all 9 perks now physically in the map**:
  Quick Revive, Jug, Speed Cola, Double Tap, Stamin-Up, Mule Kick (template
  prefabs) + Deadshot, Widow's Wine, Aura Blast (inline structs). Aura Blast
  is implemented by hijacking the **stock-but-unfinished
  `_zm_perk_electric_cherry` module** (mod tools ship it with Treyarch's own
  "TODO update these to proper settings" placeholders — cost 10, machine model
  `p7_zm_vending_nuke`, Widow's Wine hint string — i.e. a complete registered
  perk pipeline waiting for real values). New module
  [`_acc_perk_aura_blast.gsc`](scripts/zm/zm_abandoned_cyber_city/_acc_perk_aura_blast.gsc)
  overwrites the `level._custom_perks[specialty_electriccherry]` entry after
  `zm_usermap::main()` (cost 2,500, our hint string, our give/take threads —
  cherry's reload-attack never attaches) and implements the docs/13 base
  tier: 400u shockwave, 3s stun via `ASMSetAnimationRate` (the verified stock
  slow mechanism), 120s cooldown, full bosses immune, **crouch+melee chord**
  activation (BO3 has no console-command script notify — VERIFIED in
  `_acc_weapon_abilities.gsc`, whose weapon abilities own the ADS+melee
  chord). Entry `.gsc` AND `.csc` both `#using` the stock cherry module (the
  client half must match or its clientfield registration mismatches at load);
  zone gets the new `scriptparsetree` line; machine struct sits on the west
  perimeter wall. TODO(acc-localize): hint shows the raw token; custom machine
  model is Phase 5 art; Mega Man tier is Phase 3.
- **Six wallbuys** — each a `weapon_upgrade` script_struct targeting a model
  struct, copied field-for-field from `zm_alien_isolation`'s shipped wallbuy
  prefabs (every weapon name + world model + chalk material below was read
  out of that map's prefab sources):
  - **ICR-1** (`"ar_accurate"`, chalk `t7_zm_chalk_buy_icr1`) and
    **Haymaker 12** (`"shotgun_fullauto"`, no chalk) on the extended north
    wall.
  - South perimeter wall, all with chalk decals: **Bowie Knife**
    (`"bowie_knife"`, targetname `bowie_upgrade` — the stock melee-wallbuy
    variant; model `wpn_t7_zmb_knife_bowie_world`, chalk
    `t7_zm_chalk_buy_bowie`), **Drakon** (`"sniper_fastsemi"`, chalk
    `t7_zm_chalk_buy_drakon`) standing in for the sniper slot until the
    Intervention import lands (docs/05_weapons.md names it the explicit
    fallback), **Sheiva** (`"ar_marksman"`, model `wpn_t7_ar_shva_world`,
    chalk `t7_zm_chalk_buy_shiva`) standing in for the M14 EBR semi-auto-AR
    slot, and **Frag Grenade** (`"frag_grenade"`, model
    `wpn_t7_grenade_frag_world`, chalk `t7_zm_chalk_buy_frag`) standing in
    for the custom EMP Grenade tactical slot.
  - That covers every roster wallbuy slot with the best stock equivalent.
    The remaining roster guns are box-only stock weapons (Brecci, XR-2,
    Locus, Drakon — already in the stock box pool) or unported imports
    (B23R, Tac-19, AK-47, M14 EBR, G3, FN FAL, Intervention) and the custom
    EMP grenade — those need GDT/asset porting on the Windows box (Phase 4,
    docs/05_weapons.md import notes; NOT plug-and-play: each needs APE
    conversion + a `weaponfull` zone line).
  - Costs come from the stock `zm_levelcommon_weapons.csv` table for now; our
    pricing is a Phase 3 script pass.
- **TODO(acc-geom)**: Haymaker and Drakon model structs reuse
  `wpn_t7_ar_talon_world` (ICR-1's real world model; shipped prefabs prove a
  mismatched model still functions — the shipped drakon prefab itself uses
  the talon model — it only drives trigger bounds + post-buy display). Swap
  to their real world models once verified in APE on the Windows box.
- **Room enlarged to a full arena** — five new worldspawn brushes
  (`script_wall`, plane format cloned from the adjacent template brush):
  north wall extension (x 518.5→732.5, y 419.5–439.5) backing the new
  machine/wallbuy row and closing the NE floor gap, plus a perimeter around
  the whole template floor slab (south/north/west/east walls at the slab
  edges: x −1056→1094.5, y −1073.5→928, 20 thick, 256 tall). Playable space
  is now the entire ~2150×2000 slab. Zombie entry path is unchanged (window
  barricade; both riser structs and the dog spawner are in-room and inside
  the perimeter).
- **Already present from the template copy (no change needed)**: Mystery Box
  (`box_start` prefab — verified: single-chest maps ignore
  `level.start_chest_name`, stock `_zm_magicbox.gsc` size==1 branch), the six
  template perk prefabs, PaP, power switch.

### Fixed — stock-API verification pass (multi-agent, vs real Treyarch sources)

Every stock-API touchpoint in all 20 GSC files was verified claim-by-claim
against a local clone of the stock scripts (one verifier agent per file + 4
external-evidence researchers + adversarial re-check of every finding):
**211 verified clean, 52 confirmed issues fixed, 5 findings refuted.** Full
ledger with citations: **[docs/19_stock_api_verification.md](docs/19_stock_api_verification.md)**;
every fix is marked `VERIFIED(acc)` in code with stock `file:line` evidence.
The big ones (each was a silent no-op or hang, not a compile error):

- **Damage pipeline was dead**: `callback::on_ai_damage` is register-only in BO3 (no dispatch site exists in stock). Rewired `_acc_damage.gsc` to `zm::register_actor_damage_callback` with the real 12-arg signature and `-1`-passthrough return convention — headshot multipliers and damage tracking now actually run.
- **All "zombie_killed" listeners were dead** (points, elites, hack event): that notify is player-entity/no-args/insta-kill-only. Rewired to `zm_spawner::register_zombie_death_event_callback` (runs on the dying zombie, attacker arg, `self.damagemod`/`self.damagelocation`).
- **Stock kill points were never suppressed** (players would have earned stock 60/130 ON TOP of our 40/100/100): now zeroed via `zm_score::register_score_event("death"/"ballistic_knife_death")`. Point shares re-quantized to 10-pt units because `add_to_player_score` rounds UP to multiples of 10 (a 2-contributor 40-pt kill would have paid 50).
- **Flag-vs-notify hangs**: `"power_on"` and `"initial_blackscreen_passed"` are flags — five bare `level waittill` sites (entry script, main, modifiers, randomizer) replaced with `flag::wait_till`.
- **Zombie speed boost never applied**: `on_ai_spawned` dispatches with no args on the actor — handler rewritten zero-param/self, and switched from player-only `SetMoveSpeedScale` to `ASMSetAnimationRate` (the Widow's Wine mechanism).
- **Wrong weapon/perk identifiers**: BO3 names are class-based (`"shotgun_fullauto"`, `"ar_accurate"`, `"sniper_fastsemi"`, `"bowie_knife"`...) — all `<name>_zm` strings replaced; perk specialties corrected to `specialty_doubletap2`/`specialty_staminup`; melee mod string `MOD_MELEE_ASSASSINATE`; dead `"j_head"` hitloc removed.
- **Compile blockers**: GSC has no `obj.(name)` dynamic-member syntax (overclock flags now string-keyed arrays); two missing `#using scripts\codescripts\struct;`; calls to nonexistent `util::waittill_round`, `zombie_utility::get_active_zombie_spawners`, `level._zm_is_power_on()`, `zm_power::turn_power_off_all`, `zm_perks::perk_lose_on_damage` replaced with the real stock APIs (`between_round_over` loop, `level.zombie_spawners`, `flag::get/clear/set`, `perk_pause_all_perks`).
- **Ordering bugs**: `level._zombie_custom_add_weapons` must be set BEFORE `zm_usermap::main()` (consumed synchronously inside); Mystery Box initial location must be set in pre_init via `level.start_chest_name` (stock reads it ~0.05s after init); boss phase-runner threaded so its `acc_boss_dead` waittill arms before the notify; elite promotion now waits for `zombie_init_done` (frame-end spawn func clobbers health); elite teleports clamped to navmesh; Neural Boots speed re-applied each spawn (usermap template resets it); downed-player check fixed (`player.isdowned` doesn't exist → `zm_utility::is_player_valid`); direct `player.score` writes replaced with `zm_score::` API; roguelike down-watcher moved to per-player with refire debounce; express modifier now actually skips to round 10 (`zm_utility::zombie_goto_round`); emergency-drop powerups and random perk wired to the real stock helpers.
- **[docs/16_gsc_reference.md](docs/16_gsc_reference.md)** — the callbacks/damage/scoring sections were the SOURCE of several of these bugs (forum-derived, wrong); rewritten with mirror-verified dispatch sites, the on_ai_damage/on_ai_killed trap warning, flag-vs-notify, scoring quantization, and weapon-object rules. **[docs/18_first_build_checklist.md](docs/18_first_build_checklist.md)** known-risks list shrunk accordingly (subfolder layout, sound line, and `#define` risks all proven safe via shipped maps).
- External evidence (4 research agents): GSC subfolders under usermaps are proven by shipped Workshop maps (zm_nuked, UGX Mod) — our layout stays; our `.zone` validated line-by-line against 7 shipped zones; Workshop publish flow documented (Launcher generates `workshop.json`, publish does not verify a build exists — link first).

### Added — starting-room build kit (e2e path to Workshop)

- **[map_source/zm/zm_abandoned_cyber_city.map](map_source/zm/zm_abandoned_cyber_city.map)** — Radiant map source: byte-identical copy of the stock Launcher zm template starting room (player spawns, barrier + zombie spawner, `start_zone` info_volume, perk slots, PaP, Mystery Box, power switch, intermission/respawn structs, sun/umbra volumes). Sourced from the Launcher `rex/templates` ZM Base template; deliberately unmodified so the first compile is the known-good path.
- **[zone_source/zm_abandoned_cyber_city.zone](zone_source/zm_abandoned_cyber_city.zone)** — proper BO3 `.zone` manifest (`>class,zm_mod_level`, `col_map`/`gfx_map`, `scriptparsetree` for all 20 scripts, `zm_levelcommon_weapons.csv` stringtable). **Replaces** `zone_source/zm_abandoned_cyber_city.csv`, which used a WaW-era `rawfile`/CSV format BO3 does not read.
- **[sound/zoneconfig/zm_abandoned_cyber_city.szc](sound/zoneconfig/zm_abandoned_cyber_city.szc)**, **[zone/](zone/)** (loading/preview images + `workshop.json.example`) — the remaining files the Launcher build + Workshop publish expect.
- **[docs/18_first_build_checklist.md](docs/18_first_build_checklist.md)** — turnkey sync → compile → run → publish → subscribe walkthrough with failure-mode table and an honest "known risks" list.

### Changed — BO3-correctness fixes (the old scaffold would not have compiled)

- **All 18 `_acc_*.gsc` modules** — converted from WaW-era to BO3 GSC: `function` keyword added to all 206 definitions, `#namespace acc_<name>;` declared per module (file keeps the `_acc_` prefix, namespace drops the underscore, mirroring stock `_zm_utility.gsc` → `zm_utility::`), all cross-module call sites renamed (`_acc_x::` → `acc_x::`), stock namespaces corrected (`_zm_score::` → `zm_score::`, `_zm_utility::` → `zm_utility::`, etc.).
- **Entry scripts moved** from `maps/zm/` (WaW convention, wrong for BO3) to **[scripts/zm/zm_abandoned_cyber_city.gsc](scripts/zm/zm_abandoned_cyber_city.gsc)** / `.csc`, rebuilt on the stock template structure: `zm_usermap::main()` bootstrap (BO3 has no `_zm::main()`; `load::main()` runs inside the usermap framework), `start_zone` zone manager registration, stock starting weapon/points, then our three hooks (`acc_main::pre_init()`, `acc_early_round_pacing::post_zm_main()`, threaded `acc_main::init()`).
- **`_acc_main.gsc`** — removed the `client_init()` cross-VM path: a `.csc` cannot call into `.gsc` modules (separate VMs). Client-side `_acc_` work returns as real `.csc` files with the Phase 4 LUI pass. The new entry `.csc` is pure stock template.
- **[tools/sync_to_modtools.ps1](tools/sync_to_modtools.ps1)** — new layout: `scripts/`, `zone_source/`, `sound/`, `ui/` mirror into the usermap; `zone/` copies without deleting (Launcher writes `workshop.json` there); the `.map` single-file-copies into the game root `map_source\zm\` (where Radiant reads it — never mirrored, that folder holds `_prefabs/` and other maps). Reverse mode never deletes repo files; run it after every Radiant session.
- **[SETUP_WINDOWS.md](SETUP_WINDOWS.md)** — rewritten as the complete blank-machine → published-Workshop-build path: prerequisites (BO3 ownership, ~170 GB disk), line-endings guard at Git install/clone (`core.autocrlf false` — protects `.map`/`.gsc`), PowerShell execution-policy unblock, sync verify paths, build → test (dev console, expected `[acc]` output) → publish (workshop.json capture via `-Reverse` sync) → subscribe-and-verify, day-to-day iteration loop, expanded troubleshooting.
- **Docs aligned**: README (layout, conventions, first-compile status), tools/README (mapping table + modes), module README (call order via `zm_usermap::main()`, namespace convention), 01_toolchain (directory layout, `map_source` location, zone manifest pitfall), 05_weapons / 06_mechanics / 16_gsc_reference (manifest format, `weaponfull` lines, no `_zm::main()`), 08_milestones (Phase 2 deliverables).

### Changed

- **[docs/13_perks.md](docs/13_perks.md)** — **Base + Mega merged**: roster table adds **Base** and **Mega** summary columns (readable in one pass). Nine subsections each have **Base (full description)** and **Mega: … (full description)** prose paragraphs plus **Mechanics** bullets. **[Mega Bottles (system)](docs/13_perks.md#mega-bottles-system)** keeps acquisition, persistence, HUD, implementation. Cross-links updated in [REQUIREMENTS.md](REQUIREMENTS.md), [11_enemies.md](docs/11_enemies.md), [12_boss_items.md](docs/12_boss_items.md), [14_controls_and_hud.md](docs/14_controls_and_hud.md); comment in `_acc_mega_bottles.gsc`.
- **[docs/13_perks.md](docs/13_perks.md)**, **[REQUIREMENTS.md](REQUIREMENTS.md)** — **Stock *Black Ops III* vs this map:** [Player HP Baseline](docs/13_perks.md#player-hp-baseline) states retail **Jug** (**5** melee hits with Jug from full, **3** without); this map keeps authoritative **3 / 6** (**6** with Jug = **+1** vs stock Jug). **Speed Cola** retail = **+50%** reload + faster barrier boards — **not** faster perk drink or weapon swap (those are map-only). **Double Tap II** retail = **+33%** RoF + **double-bullet** damage model; this map documents **+3%** damage as a **stacking abstraction** for Phase 3. Wiki links added for Juggernog / Speed Cola / Double Tap Root Beer.

## [v0.14.0] - Perk rebalance (base + Mega numbers)

### Changed

- **[docs/13_perks.md](docs/13_perks.md)** — Full alignment of prose **Mechanics** with roster table: **Jug** Mega = +1 hit + **boss-ability immunity**; **QR** Mega = **×0.6** revive vs base QR + **+15% move** while any teammate is down; **Speed** Mega = **+65%** reload + **+15%** gun switch / perk drink; **Double Tap** Mega = **+50%** RoF + **+6% total** damage; **Stamin-Up** base = **stock BO3** longer sprint + faster sprint; **The Flash** Mega = longer sprint + **+12%** run + **×2** walk + **×4** crawl (**not** unlimited sprint); **Mule Kick** = **2,500** pts; **Armory** = **+30%** ammo + **+2** lethal **+2** tactical; **Deadshot** Mega = **×1.75** headshot + **no recoil**; **Widow** Mega = zombie-only **OHK** melee + **OHK** web nades on regulars + **6** web nades; **Aura** base (**bosses immune**); **Mega Man** = still 800u / 60s / 2 charges + **bosses can be stunned** (tuned). Roster table removes **“Unchanged:”** wording in favor of plain perk effects. Buying all 9 base perks = **26,500** Points. Mega damage example uses **×1.75** for American Sniper.
- **[docs/15_coop_rules.md](docs/15_coop_rules.md)** — **Mule Kick** cost callout **2,500** (was 4,000).

### Note (historical)

- Mega variant **effect numbers** in the **v0.11.0** changelog entry are superseded by this doc pass; use [13_perks.md](docs/13_perks.md) as source of truth.

## [v0.13.0] - Map layout diagram + decontamination zones

### Added

- **[docs/03_layout.md](docs/03_layout.md)** — ASCII + mermaid **map diagrams** (topology, safe vs sealable zones). **Decontamination** rules: rounds **1–4** each **permanently seal** one of **Market, Alley, Server Vault, Rooftop Helipad** (random permutation at map load); **20s** evacuation window at round start or **death**; **Spawn, Corporate Plaza, Lab never seal** (hub + progression).
- **Perk timing**: Lab **4-of-9 perk re-roll runs only after** decontamination completes — updated [docs/13_perks.md](docs/13_perks.md), [docs/06_mechanics.md](docs/06_mechanics.md) §4, [REQUIREMENTS.md](REQUIREMENTS.md). Stub comment in [`_acc_map_randomizer.gsc`](scripts/zm/zm_abandoned_cyber_city/_acc_map_randomizer.gsc) for future `acc_decontamination_complete` wait.

---

## [v0.12.0] - Early round pressure (faster + more zombies, rounds 1–4)

### Added

- **Design**: Opening rounds are no longer a slow stock walk phase. Rounds **1–4** use higher spawn totals and faster zombie movement so the start of a run is a deliberate **setup phase** (doors, lanes, Lab check, economy). See [docs/06_mechanics.md](docs/06_mechanics.md) § Early round pressure; [docs/04_progression_and_skills.md](docs/04_progression_and_skills.md) difficulty table.
- **Module** [`_acc_early_round_pacing.gsc`](scripts/zm/zm_abandoned_cyber_city/_acc_early_round_pacing.gsc):
  - `post_zm_main()` chains `level.max_zombie_func` to multiply stock output by **×1.40** (round 1) and **×1.35** (rounds 2–4), `ceil` to int. Multiplies with `level.acc_mod_round_zombie_mult` when set (e.g. Shortened Rounds).
  - `init()` registers `callback::on_ai_spawned` to apply **`setmovespeedscale( 1.15 )`** to zombies in rounds **1–4**. Skipped when **Sprint** modifier sets `level.acc_mod_force_sprint`.
- **Map wiring**: [`maps/zm/zm_abandoned_cyber_city.gsc`](maps/zm/zm_abandoned_cyber_city.gsc) calls `post_zm_main()` immediately after `_zm::main()` so the spawn override exists before round 1.
- **Docs**: [docs/16_gsc_reference.md](docs/16_gsc_reference.md) — `level.max_zombie_func( n_max, n_round )` delegation pattern.

### Constants (sync with docs)

- `ACC_EARLY_ROUND_MAX` = 4, `ACC_EARLY_SPAWN_MULT_R1` = 1.40, `ACC_EARLY_SPAWN_MULT` = 1.35, `ACC_EARLY_SPEED_SCALE` = 1.15.

---

## [Unreleased]

Tracked changes planned but not yet applied.

- Author FN FAL, Tac-19, Intervention, M14 EBR, G3, AK-47, B23R weapon GDTs (Phase 4 work).
- Author Signal Staff + Vibro Cleaver wonder weapon GSC modules.
- Author LUI widgets for all custom HUD elements (Data Shards counter, Cyberware stack, weapon status, items row, objective prompts, boss health).
- Wire ability hotkey through LUI binding screen.
- Suppress stock BO3 kill-point awards so our 40/100/100 replaces rather than adds. (Researched options documented in `_acc_points.gsc::init` comment.)

---

## [v0.11.0] - Mega Bottle perk-upgrade system

### Added

- **Empty Mega Bottle** item: guaranteed drop from every boss kill (mini + full), **1 per player**. Separate from the 6-item boss-drop pool. Counter tracked on `self.acc_mega_bottles`.
- **9 Mega perk variants** with themed names:
  - Jugger-Nog → **Ultimate Tank** (immune to boss stuns + 1 extra hit)
  - Quick Revive → **Savior** (revive at 35% time + +15% speed post-revive for both players)
  - Speed Cola → **Sleight of Hand Expert** (+65% reload + faster drink/swap/lethal)
  - Double Tap 2.0 → **Gun Slinger** (+50% fire rate)
  - Stamin-Up → **The Flash** (unlimited sprint + +10% walk + +12% sprint)
  - Mule Kick → **The Armory** (+35% ammo per gun + double grenade capacity)
  - Deadshot → **American Sniper** (+2x headshot + zero recoil)
  - Widow's Wine → **Spiderman** (grenade 1-shot zombies + hold 6)
  - Aura Blast → **Mega Man** (2x radius + 60s CD + 2 charges)
- **Mega application**: at a Lab perk machine currently dispensing a perk the player owns, consume 1 bottle → perk becomes Mega. No additional Points cost. Must be in current rotation.
- **Sticky Mega flag**: Mega state persists through death for the rest of the run. Re-buying the perk after respawn re-applies Mega automatically. Flag cleared only at run end.
- **New module** [`_acc_mega_bottles.gsc`](scripts/zm/zm_abandoned_cyber_city/_acc_mega_bottles.gsc) - bottle acquisition, inventory tracking, Mega flag storage, clientfield for HUD counter, machine-interaction entry point, display-name helpers for all 9 Mega variants.
- **HUD counter** for Mega Bottles (`Bottles: N`) adjacent to Data Shards counter, hidden when count is 0. LUI widget planned for Phase 4; `iprintln` fallback for Phase 3.

### Changed

- [docs/13_perks.md](docs/13_perks.md) - major new section "Mega Bottles (upgraded perk variants)" with acquisition loop, usage rules, persistence rule, timing tension with rotation, the 9 Mega variants in detail, co-op notes, HUD notes, implementation pointers, and 4 tuning levers.
- [docs/11_enemies.md](docs/11_enemies.md) - mini-boss and full-boss entries both list the new guaranteed Mega Bottle drop.
- [docs/12_boss_items.md](docs/12_boss_items.md) - clarifies that it covers the 6-item equippable pool only, cross-references the sibling Mega Bottle system.
- [docs/14_controls_and_hud.md](docs/14_controls_and_hud.md) - new HUD element "Mega Bottle counter" (1b) adjacent to Data Shards counter.
- [scripts/zm/zm_abandoned_cyber_city/_acc_boss.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_boss.gsc) - both `watch_mini_boss_death` and the full-boss death path now call `_acc_mega_bottles::on_boss_death` in addition to the existing `_acc_boss_items::on_boss_death`.
- [scripts/zm/zm_abandoned_cyber_city/_acc_main.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_main.gsc) - new module included in init sequence + per-player connect callback.
- [zone_source/zm_abandoned_cyber_city.csv](zone_source/zm_abandoned_cyber_city.csv) - new module registered.
- [scripts/zm/zm_abandoned_cyber_city/README.md](scripts/zm/zm_abandoned_cyber_city/README.md) - module table, call order, and per-player state conventions updated for Mega Bottle system.
- [REQUIREMENTS.md](REQUIREMENTS.md) - perk summary + code↔doc mapping include the new Mega system.

### Design Decisions Taken

- **Bottle cost is bottle only** (no extra Points). Base perk Points spend is the "first payment"; bottle is the "upgrade currency." Cleaner UX.
- **Must be in rotation** to apply Mega. Adds a second timing layer on top of the per-round rotation. If this feels too punishing in playtest, decouple (allow Mega at any machine regardless of rotation) — flagged as a tuning lever.
- **Per-player, not per-team**: each player gets their own bottle per boss kill. 4p co-op = 4 bottles per boss across the team.

### Known Balance Risks

- **American Sniper + full Cyberware/Overclock/PaP L5 stack** produces insane headshot damage (~100x+ on regulars, ~160x+ on boss headshots). Intended as a power fantasy; playtest decides if it crosses into "unfun-absurd."
- **Ultimate Tank "immune to boss stuns"** needs explicit scope — Phase 4 TODO. First-pass: fully skip all phase debuff effects. Could soften to 50%.
- **Double lethal/tactical capacity from The Armory** stacks with Spiderman's "hold 6" → Frag max becomes 8 (double of 4) with Armory alone, 6 cap with Spiderman, min of the two = 6. Clarified in the doc.

---

## [v0.10.0] - per-round perk rotation at the Lab

### Added

- **All 9 perks consolidated to the Lab** (4 perk machines: `acc_lab_perk_a/b/c/d`).
- **Per-round rotation**: at every round start (`acc_round_start` notify), machines re-roll to a random 4-of-9 perks from the full roster. No duplicates.
- New function [`_acc_map_randomizer.gsc::roll_perk_rotation(round_number)`](scripts/zm/zm_abandoned_cyber_city/_acc_map_randomizer.gsc) that emits `acc_perk_rotation_rolled` level notify on roll.
- New function [`_acc_map_randomizer.gsc::apply_perk_rotation_to_machines(rotation)`](scripts/zm/zm_abandoned_cyber_city/_acc_map_randomizer.gsc) that reads Radiant `targetname` lookups and sets per-machine `acc_current_specialty` (Phase 4 visual re-skin is a TODO).
- Listener loop [`_acc_map_randomizer.gsc::watch_round_for_perk_rotation()`](scripts/zm/zm_abandoned_cyber_city/_acc_map_randomizer.gsc) that subscribes to `acc_round_start`.
- Helper [`_acc_map_randomizer.gsc::get_full_perk_roster()`](scripts/zm/zm_abandoned_cyber_city/_acc_map_randomizer.gsc) as the single source of truth for the 9 specialty names.

### Changed

- [docs/13_perks.md](docs/13_perks.md) - slot assignment section fully rewritten: 4 Lab machines, per-round rotation, probability tables (Jug-less odds, consecutive-miss probabilities), route/patience player-adaptation notes.
- [docs/03_layout.md](docs/03_layout.md) - perk slots **removed** from Market, Corp Plaza, Server Vault, Rooftop Helipad. Lab now lists 4 perk machines. Lab's description flags it as "highest-traffic zone in the map" due to rotation visits. Randomized-elements list updated to "Perk rotation (per round)".
- [docs/07_replayability.md](docs/07_replayability.md) - perk section rewritten: per-round not per-run; probability notes; variance math updated.
- [REQUIREMENTS.md](REQUIREMENTS.md) - perk summary reflects all-Lab rotation model.
- [scripts/zm/zm_abandoned_cyber_city/_acc_map_randomizer.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_map_randomizer.gsc) - `pre_init` no longer rolls `state.perk_pool`; `apply_state_when_ready` no longer calls `apply_perk_pool`; `log_state` no longer logs perk slots (rotation logs its own per-round).

### Removed

- `roll_perk_pool()` function (replaced by per-round `roll_perk_rotation`).
- `apply_perk_pool()` function (replaced by `apply_perk_rotation_to_machines`).
- `state.perk_pool` field on `level.acc_map_state`.
- **Zone-distributed perk machines**: perk machines at Market / Corp / Server Vault / Rooftop Helipad are gone.
- Jug / Quick Revive "guaranteed in specific zone" rules. Both are now equal-weighted in the rotation.
- Old per-run 420-configuration count (replaced by per-round 126 rotations, 50 per run = far more variance).

### Known Tuning Risks

- **Jug-less early runs**: ~5% of runs will see no Jug until round 6+. If this feels terrible in playtest, options:
  1. Weight Jug 2x (roughly doubles appearance odds).
  2. Guarantee Jug in round 1's rotation (player gets Jug within a minute).
  3. Add a "hasn't appeared in 5 rounds" pity-timer that forces Jug next roll.
- **Lab choke during round transitions**: with 4 players all rushing to Lab simultaneously at round start, the zone could feel crowded. Playtest; consider widening Lab geometry if so.
- **Some rounds offer nothing useful**: if the RNG gives a player 4 perks they already own, the Lab trip is wasted. Intended tension but worth watching; if too frequent, add "skip-reroll button" (costs Points to force a re-roll).

---

## [v0.9.0] - perk overhaul

### Added

- **Aura Blast** (custom active perk, 2,500 Points) — hold [perk ability key] to stun all enemies within 400u for 3s. 120s cooldown. Replaces Lattice Bond.
- **Deadshot** (custom, 3,500 Points) — +1.5x headshot multiplier + auto-aim to head when ADS. Stacks multiplicatively with our 2x/3x headshot system. Auto-aim disabled against bosses. Replaces Void Cache.
- **Widow's Wine** (custom, 4,000 Points) — stock web-grenade mechanics + +50% damage/radius to both Frag Grenade and EMP Grenade. New addition.
- **No 4-perk cap** — stock BO3's per-player limit is explicitly removed in this map. Players can hold all 9 perks simultaneously.
- **Perk ability hotkey** (`acc_perk_ability` notify, default G / D-pad Up) — separate from weapon ability hotkey so players can chain both. Documented in [docs/14_controls_and_hud.md](docs/14_controls_and_hud.md).
- **Baseline HP rule** documented: 3 zombie melee hits to die without Jug, 6 hits with Jug. Authoritative tuning target.
- **Per-run perk lockout** — 4 of 7 rotatable perks are excluded per run (randomized). 420 distinct configurations possible.
- Console logging added to `_acc_map_randomizer.gsc::roll_perk_pool` for the 4 locked-out perks so playtest can see run state.

### Changed

- **Jugger-Nog** cost: stock 2,500 → **4,000**. HP doubling preserved.
- **Quick Revive** cost: 500/1,500 → **2,500**. Added **+30% health regen speed after damage**. Faster-revive preserved.
- **Speed Cola** cost: 3,000 → **3,500**. Added **faster perk drinking** + **faster equipment change**. +50% reload preserved.
- **Stamin-Up**: speed buff **+5% → +10%**. Changed **unlimited sprint → extended sprint** (~2x stock duration). Significant nerf to stock behavior.
- **Mule Kick** cost: stock 4,000 → **3,000**.
- **Double Tap 2.0**: unchanged.
- Perk total: 8 → **9** (added Widow's Wine; replaced Lattice Bond + Void Cache with Aura Blast + Deadshot + Widow's Wine).
- [docs/13_perks.md](docs/13_perks.md) fully rewritten with new tuning, the "Swiss Army Player" full-stack example, implementation status, and tuning levers.
- [docs/12_boss_items.md](docs/12_boss_items.md) Ghost Shroud stacking notes updated (no longer references Lattice Bond; now references Jug + Aura Blast for the clutch-survival layer).
- [docs/06_mechanics.md](docs/06_mechanics.md) - Deadshot effective damage table added; stacking chain updated; Void Cache notes in co-op section replaced with Widow's Wine + Deadshot notes.
- [docs/07_replayability.md](docs/07_replayability.md) - perk roster list corrected to 9-perk set; build archetype notes updated.
- [docs/05_weapons.md](docs/05_weapons.md) - removed inline Lattice Bond / Void Cache perk descriptions; now delegates entirely to [13_perks.md](docs/13_perks.md) with a weapon-relevance summary.
- [docs/16_gsc_reference.md](docs/16_gsc_reference.md) section 5 - custom perk creation example updated to Aura Blast (active-perk pattern). Added patterns for active perks, damage-modifier perks, and grenade-boost perks.
- [docs/08_milestones.md](docs/08_milestones.md) Phase 4 deliverables - custom perk list updated.
- [REQUIREMENTS.md](REQUIREMENTS.md) - perk summary updated to 9 perks + no cap + 3/6 HP rule.
- [scripts/zm/zm_abandoned_cyber_city/_acc_map_randomizer.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_map_randomizer.gsc) - `roll_perk_pool` updated to 7-perk rotatable pool, logs 4 locked-out per run.

### Removed

- **Lattice Bond** perk (replaced by Aura Blast).
- **Void Cache** perk (replaced by Deadshot - different role but same "3rd custom perk" slot).
- **4-perk cap** enforcement.

### Tuning Notes

Watch in playtest:
- Deadshot + 3x boss headshot multiplier + Overload Cyberware + Precision Mode ability = absurd boss-damage stack. Tuning levers in [docs/13_perks.md](docs/13_perks.md).
- Widow's Wine damage boost on Frag might make Meltdown-capstone grenade spam dominant. Consider reducing +50% to +25% if this validates.
- Aura Blast 2,500 is cheap for what it does (on-demand 3s AoE stun). Could bump to 3,000-3,500 if it trivializes mid-game.

---

## [v0.8.0] - BO3 API research + verified fixes

### Added

- **[docs/16_gsc_reference.md](docs/16_gsc_reference.md)** — BO3 GSC/CSC language + API reference doc. Verified signatures (via modme forums, bo3explorer, UGX Mods wiki) for `callback::on_ai_damage`, `_zm_score::add_to_player_score`, `clientfield::register`, `zombie_killed` notify, common utility modules, custom perk workflow, custom weapon import workflow, debug loop, common gotchas.
- **[docs/17_reference_maps_study.md](docs/17_reference_maps_study.md)** — Design patterns study covering Ameliorama I/II, Machin[a], Shadows of Evil, Der Eisendrache, Origins. What we took from each, what we explicitly rejected, open questions, maps queued for future study.

### Changed

- **[scripts/zm/zm_abandoned_cyber_city/_acc_damage.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_damage.gsc)** — `on_ai_damage` callback signature corrected to canonical BO3 order: `(str_mod, str_hit_location, v_hit_origin, e_player, n_amount, w_weapon, ...)`. Previous approximated order was wrong. Added `weapon_root_name()` helper to handle weapon struct vs string gracefully.
- **[scripts/zm/zm_abandoned_cyber_city/_acc_points.gsc](scripts/zm/zm_abandoned_cyber_city/_acc_points.gsc)** — `award_player()` now uses `player _zm_score::add_to_player_score(pts)` instead of direct `player.score += pts`, so HUD floaters and VO cues fire correctly. Added `#using scripts\zm\_zm_score;`.
- Stock-kill-award suppression TODO upgraded to a concrete research plan in `_acc_points.gsc::init()` with three possible community-standard paths.
- **[REQUIREMENTS.md](REQUIREMENTS.md)** — new "Reference Material" section indexing the two new docs. Code↔doc mapping annotates which scripts reference the GSC reference for verified APIs.

### Resolved TODO(acc-verify) markers

- `_acc_data_shards.gsc` — `clientfield::register` signature verified.
- `_acc_data_shards.gsc` — `is_player_alive` now documented to prefer `_zm_utility::is_player_valid` when available, with a manual fallback.
- `_acc_utility.gsc` — `level.players` iteration pattern confirmed as canonical.
- `_acc_damage.gsc` — zombie team string `"axis"` confirmed.
- `_acc_events_hack.gsc` — `"head"` / `"helmet"` hit locations confirmed for headshot detection.
- `_acc_points.gsc` — `MOD_MELEE` / `MOD_MELEE_WEAPON_BUTT` / `MOD_MELEE_ASSASSINATION` as the knife MOD strings.

### Remaining TODO(acc-verify) markers

Still need first-Mod-Tools-compile verification:

- `_acc_overclocks.gsc` PaP suffix naming (exact strings).
- `_acc_map_randomizer.gsc` Mystery Box weapon registration API call shape.
- `_acc_elites.gsc` zombie spawn + promotion pipeline (stock flow is tangled; community helpers exist).
- `_acc_modifiers.gsc` `util::waittill_round` stock helper existence.
- `_acc_cyberware.gsc` exact move-speed multiplier API (`setmovespeedscale` or equivalent).

These are documented in the code with current best-guess implementations and fallback strategies.

---

## [v0.7.0] - Payroll Ledger (6th boss-drop item)

### Added

- **Payroll Ledger** boss-drop item (implant slot): +10% Points on any kill the wearer contributes to. Applied after the 70/30 co-op split (on the player's share, not the base award).
- Boss-item pool expanded from 5 to 6 items. Player inventory still 2 slots; drop chance unchanged (mini 50%, full 100%); duplicate → 3 Shards unchanged.
- `ACC_POINTS_LEDGER_MULT = 1.10` constant in `_acc_points.gsc`.
- `ACC_ITEM_LEDGER_POINTS_MULT = 1.10` constant in `_acc_boss_items.gsc` (exposed for cross-module reference).
- Helper `_acc_boss_items::player_has_ledger()`.
- Stacking rules documented: multiplicative with Double Points, independent from Void Cache tokens, cannot stack with itself.

### Changed

- [docs/12_boss_items.md](docs/12_boss_items.md) - updated item count throughout, new "Why 2 slots out of 6" rationale, new synergistic combo examples (Ledger + Battery, Ledger + Shroud), tuning levers updated.
- [docs/05_weapons.md](docs/05_weapons.md) - boss-items cross-reference updated to 6 items + Ledger interaction note.
- [docs/13_perks.md](docs/13_perks.md) - Void Cache section adds Ledger stacking note.
- [REQUIREMENTS.md](REQUIREMENTS.md) - item pool size and per-system summary updated.
- [scripts/zm/zm_abandoned_cyber_city/README.md](scripts/zm/zm_abandoned_cyber_city/README.md) - module table updated to reflect dependency on `_acc_points.gsc` for the Ledger bonus.

### Fixed

- Stale "Overclock Active Pool" text in [docs/07_replayability.md](docs/07_replayability.md) that described the pre-Tier-1-5 design ("3 per family, rerolled per run"). Replaced with the current per-tier-up draw model matching [05_weapons.md](docs/05_weapons.md).

---

## [v0.6.0] - docs established as requirements

### Added

- `REQUIREMENTS.md` at repo root. Master index of every game system with change-control policy. Designated as the authoritative requirements document.
- `docs/13_perks.md` - full perk spec (6 stock + 2 custom perks, per-run slot randomization rules, custom perk cooldown details, stacking/interaction rules, tuning levers).
- `docs/14_controls_and_hud.md` - input bindings, HUD element list with layout sketch, LUI widget file plan, accessibility notes.
- `docs/15_coop_rules.md` - consolidated co-op behavior (HP scaling, spawn-rate scaling, revive rules, per-player vs shared resources, item pickup priority, side-event activator gating).
- `CHANGELOG.md` at repo root.

### Changed

- Audited existing docs; fixed stale references to removed weapons (Sheiva, HVK-30, Gorgon, Kuda, M1911, Argus) and to the old PaP II system in `03_layout.md`, `06_mechanics.md`, `07_replayability.md`.

---

## [v0.5.0] - weapon progression overhaul + boss items

### Added

- PaP L1-L5 system (money track, 5k / 7.5k / 10k / 12.5k / 15k, cumulative +20% damage + 1 reserve mag per level, 50k total to max).
- Tier 1-5 system (Shards track, 1 / 2 / 3 / 4 / 5, each tier unlocks 1 Overclock slot, 15 Shards total to max).
- Per-category weapon abilities: Triple Tap, Stabilizer, Precision Mode, Slug Round, Thermal Vision, Whirlwind, Extended Fuse, Overcharge.
- Boss-drop item system: 5 items (Neural Boots, Overclocked Gauntlets, Targeting Visor, Kinetic Battery, Ghost Shroud), 2 player slots, mini-boss 50% / full boss 100% drop chance, duplicates → 3 Shards.
- New modules: `_acc_weapon_abilities.gsc`, `_acc_boss_items.gsc`.
- New doc `docs/12_boss_items.md`.

### Changed

- `_acc_overclocks.gsc` refactored: removed "per-run 3 active per family" roll; replaced with per-weapon tier-up draw system.
- `_acc_boss.gsc` now triggers boss-item drops on death.
- Overclock pools no longer re-rolled per run; full family pool is draftable across tier-ups.
- Docs `04_progression_and_skills.md` updated with per-sink Shard spend table showing round 30 decision tension.

---

## [v0.4.0] - kill-point overhaul + headshot multiplier

### Added

- Headshot damage multiplier: 2x regular / 3x boss, multiplicative with stock per-weapon headshot multiplier. Tac-19 explicitly excluded.
- Kill-point replacement system: 40 regular / 100 headshot / 100 knife.
- Co-op kill-point split: 70% killer / 30% pool split among qualifying damage contributors. Solo = 100%.
- Anti-exploit rules (7 hard-enforced): min-contribution threshold, per-player damage cap at maxhealth, per-player aggregation, environmental damage exclusion, disconnect handling, invalid-killer fallback, integer rounding remainder-to-pool.
- New modules: `_acc_damage.gsc`, `_acc_points.gsc`.

### Changed

- `docs/06_mechanics.md` Point Economy section fully rewritten with example payout tables.

---

## [v0.3.0] - wonder weapons and sniper rework

### Added

- Two wonder weapons: **Signal Staff** (ranged, counters Subroutine Core with +300%) and **Vibro Cleaver** (wonder melee, counters Juggernaut Host with +300%).
- Wonder weapon craft gating: Signal Staff requires Vault Overload completion, Vibro Cleaver requires Hack Terminal completion (+ 5 Shards each).
- Boss counter pairings documented in [docs/11_enemies.md](docs/11_enemies.md).

### Changed

- Sniper tier swap: Drakon promoted to **strong** (box), Intervention demoted to **normal** (wallbuy), Locus remains **bad** (box).
- Replaced previous "candidates" (Nanite Swarm / EMP Railgun / Code Injection Pistol) with committed Signal Staff + Vibro Cleaver.
- Tac-19 design locked: no headshot multiplier applies; base damage bumped to compensate; **best crowd-control gun** in the roster.

### Removed

- Wonder weapon candidate list; those three are now "post-1.0" ideas at most.

---

## [v0.2.0] - 16-weapon roster finalized

### Added

- 3-tier-per-category weapon structure: normal (wallbuy), bad (box), strong (box).
- Final roster of 16 weapons locked:
  - Pistol: B23R (import, starter).
  - Shotgun: Haymaker 12 / Brecci / Tac-19.
  - AR full-auto: ICR-1 / XR-2 / AK-47.
  - Semi-auto AR: M14 EBR / G3 / FN FAL (all imports).
  - Sniper: Drakon / Locus / Intervention.
  - Melee: Bowie Knife.
  - Grenades: Frag + EMP Grenade (custom tactical).
- Mystery Box pool registered in `_acc_map_randomizer.gsc::register_mystery_box_pool`.

### Removed

- Previous short-list weapons that didn't survive roster review: Sheiva, HVK-30, Kuda, Argus, Bulldog, Gorgon, BRM, M1911.

---

## [v0.1.0] - weapons and enemies docs split

### Added

- `docs/05_weapons.md` (weapons-only; extracted from combined `05_weapons_and_enemies.md`).
- `docs/11_enemies.md` (enemies-only, bestiary).

### Removed

- `docs/05_weapons_and_enemies.md` (replaced by two docs above).

---

## [v0.0.0] - initial project scaffold

### Added

- Repo scaffold: `README.md`, `ROADMAP.md`, `SETUP_WINDOWS.md`.
- Design docs 00-10 covering overview, toolchain, learning path, layout, progression, mechanics, replayability, milestones, language/publishing, today-quickstart.
- Radiant entry scripts: `maps/zm/zm_abandoned_cyber_city.gsc` + `.csc`.
- 12 GSC modules under `scripts/zm/zm_abandoned_cyber_city/` covering custom data shards, cyberware, elites, events, emergency drop, modifiers, boss, map randomizer, main orchestrator, utility helpers.
- Zone source CSV.
- Windows sync tooling (`tools/sync_to_modtools.ps1`).

---

## Change Entry Guidance (for future updates)

When changing the game, append a new section following this template:

```markdown
## [vX.Y.Z] - brief title

### Added
- ...

### Changed
- ...

### Removed
- ...

### Fixed
- ...
```

Keep entries tight: one line per change, link to the doc the change applies to.

Increment:
- **x** when the change breaks previous design (e.g. replacing a whole system).
- **y** when adding new systems or substantial reworks.
- **z** for bug fixes, tuning pass deltas, small doc edits.

For every entry, update the corresponding detailed doc in `/docs` and the summary in `REQUIREMENTS.md` if the change is visible at that level.
