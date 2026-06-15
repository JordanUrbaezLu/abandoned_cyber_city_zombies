# 27 — UI System Plan (touchpoints, components, rollout)

> The map has ~20 UI touchpoints. Building each by hand = inconsistent + slow.
> Instead: **one reusable, themed component library** (`_acc_ui`), then roll it
> out everywhere. This doc is the inventory + design system + roadmap.
>
> **Technique decision is pending** the perk/PaP UI research (workflow
> `perk-info-ui-research`): a real **LUI tooltip** (Lua widget, premium) vs a
> **server-HUD card** (font strings + a translucent box, ships now). The
> component API below is written to be technique-agnostic so the renderer can be
> swapped (server-HUD v1 → LUI later) without rewriting every call site.

## Design language (Cyber City)

- **Palette:** dark translucent panels (`(0,0,0)` @ ~0.55 alpha); cyan `(0.3,0.85,1.0)`
  primary; purple `(0.55,0.35,0.95)` for PaP/tech; amber `(1.0,0.85,0.2)` for
  values/damage; red `(0.9,0.12,0.12)` for danger/low-HP; green for good.
- **Type:** large title, medium subtitle/price, small body bullets. Bullets use
  a leading glyph + tier/effect color.
- **Layout zones (avoid collisions):** top-center = zone/boss; bottom-left =
  shards/bottles/health; bottom-right = points/PaP tier; center-right or
  lower-center = the contextual **info card**; center = warnings/toasts.
- **Motion:** fade in/out (~0.15s), subtle; no jarring pops.

## Reusable component library (`_acc_ui.gsc`, to build)

| Component | API (sketch) | Used by |
|---|---|---|
| **info_card** | `acc_ui::card(player, {title, price, sections:[{label, color, bullets[]}]})` show/hide | perks, Mega, PaP, wallbuys, Cyberware nodes, Overclocks |
| **panel/box** | `acc_ui::box(player, w, h, anchor)` → translucent bg elem | backing for every card/menu |
| **toast** | `acc_ui::toast(player|all, text, color, secs)` | events, pickups, tier-ups (replaces bare iprintlnbold) |
| **warning** | `acc_ui::warning(all, title, countdown_secs)` | decontamination, boss phases, hack/overload |
| **bar** | `acc_ui::bar(owner, frac, color, label)` | player HP, boss HP, progress |
| **counter** | `acc_ui::counter(player, icon, label, value)` | shards, bottles |
| **prompt** | styled hint string helper | device/trigger hints |

Once `_acc_ui` exists, each touchpoint becomes a few lines of data + one call.

## Touchpoint inventory

| # | Touchpoint | Current state | Target | Priority |
|---|---|---|---|---|
| 1 | **Perk purchase** | 3 plain lines (`_acc_perk_info`) | info_card: name, price, **base + Mega bullets** | **P0 (now)** |
| 2 | **Pack-a-Punch** | tier label + iprintln | info_card: 5-tier ladder + benefits + next cost | **P0 (now)** |
| 3 | **Mega upgrade prompt** | stock hint string | card: "Mega: <name>" + bullets + cost (1 bottle) | P1 |
| 4 | **Wall buys** | stock name+price | card: weapon name, price, ammo/role bullet | P1 |
| 5 | **Cyberware tree** | shards HUD only; no browse/buy UI | **menu/tree UI**: nodes, branches, costs, effects | **P0-big** |
| 6 | **Overclocks** | none/stub | selection UI: roll/pick, slots, effect bullets | P1-big |
| 7 | **Mystery box** | stock | reveal polish (later) | P3 |
| 8 | **Decontamination warning** | iprintlnbold | warning component + countdown + zone tag | P1 |
| 9 | **Hack / Overload events** | iprintln | warning/toast + objective | P2 |
| 10 | **Per-run modifiers** | log only | start-of-run card listing active modifiers | P2 |
| 11 | **Boss HP + name** | done (server bar) | restyle into `bar` + phase telegraphs | P2 |
| 12 | **Player HP bar** | done | restyle into `bar` | P2 |
| 13 | **Shards / Bottles counters** | labeled text | `counter` w/ icon | P2 |
| 14 | **Floating damage #s** | done | keep; optional crit color | P3 |
| 15 | **Zone signage** | done | keep; optional icon | P3 |
| 16 | **Rampage Inducer device** | hint string | card on approach (what it does) | P2 |
| 17 | **Emergency drop** | ? | toast/prompt | P2 |
| 18 | **Buyable ending / quest** | ? | objective HUD | P3 |
| 19 | **Round / wave info** | stock | optional banner | P3 |
| 20 | **Controls / ability prompts** | iprintln | prompt helper + first-use hints | P3 |

## Status (2026-06-13)

- **Technique decided: server-HUD card** (LUI deferred to Phase 4 — it needs a
  whole client-VM pipeline + link-cycle-per-tweak for a proximity tooltip; the
  `_acc_ui` API hides the renderer so a later LUI swap won't touch call sites).
- **Foundation built: `_acc_ui.gsc`** — the reusable `card_show/card_hide`
  component (translucent box + accent strip + big title + gold price + color-coded
  bullet pool, auto-height via `setShader`).
- **P0 done:** perk card + PaP card live in `_acc_perk_info` (all 9 perks with
  base + Mega bullets; PaP shows the 5-tier ladder).
- **LUI migration (2026-06-13):** the LUI client pipeline is live (docs/28), so
  **touchpoint 1 (perk card) is now PREMIUM LUI**, not the server-HUD card. The
  card is a classed widget `CoD.AccPerkCard` in `acc_hud.lua` (room_manager pattern),
  driven by the `accPerkCard` clientuimodel int from `_acc_perk_info` (the brain).
  Context-coloured (buy/Mega/maxed/PaP). Remaining touchpoints (Mega prompt, wallbuy,
  Cyberware menu, counters, boss bar) reuse this LUI substrate next; the `acc_ui`
  server-HUD card stays as a non-LUI fallback. LUI was the Phase-4 "ceiling" below -
  it landed early.
- **PaP overhaul (2026-06-13):** the card now lists the **scaling re-pack cost
  per tier** (T2 2500 / T3 5000 / T4 7500 / T5 10000) and no longer mentions
  alt-ammo. Backing mechanic in `_acc_pap_levels`: stock **AAT disabled**
  (`level.aat_in_use = false`, no turned/fireworks rerolls), stock re-pack
  blocked for upgraded guns (`level.pack_a_punch.custom_validation`), and a
  parallel `acc_pap_tier` `trigger_radius_use` charges the scaling cost via
  `zm_score::can_player_purchase`/`minus_to_player_score`. Held-weapon tier HUD
  moved to **bottom-left** next to the gun. **`%`→"pct"** everywhere (the HUD
  font renders `%` as `.`).
- **Perk card Mega view (2026-06-14):** the four card modes are now: **buy** (0)
  base name + price + base bullets; **Mega preview** (1, own base) title = Mega
  name, "Mega upgrade: 1 Bottle", the bullets the bottle adds; **owns Mega** (2)
  title = **"Mega: <name>"** (the Mega name replaces the perk name), and a **single
  merged "effective benefits" list** (`megaFull` in `acc_hud.lua`) — every benefit
  you have, with each Mega stat **replacing** the base stat it supersedes (no
  "+50%" *and* "+70%" — just "+70%"), kept in the yellow Mega colour; **PaP** (3)
  next-tier only. Previously mode 2 stacked the full base list (cyan) over the Mega
  list (gold), repeating superseded stats.

## Roadmap

1. ~~**Foundation** — technique + `_acc_ui` component.~~ ✅
2. ~~**P0** — perk card (1), PaP card (2).~~ ✅
3. **P0-big** — Cyberware tree UI (5): the headline differentiator; needs a
   browsable node menu (its own sub-design).
4. **P1** — Mega card (3), wallbuy card (4), Overclock UI (6), decon warning (8).
5. **P2** — migrate existing HUD (11-13,16,17) onto the components; modifiers (10),
   events (9).
6. **P3** — polish pass (7,14,15,18-20) + the LUI upgrade if/when we commit to it.

## Notes

- Server-HUD is the pragmatic v1 (ships now, all-GSC). LUI is the premium ceiling
  (Phase-4: `.csc` + `rawfile,ui/uieditor/widgets/*.lua` + clientfield bridge);
  the `_acc_ui` API hides the renderer so a later LUI swap doesn't touch call sites.
- The Cyberware tree (5) is the biggest UI lift and the map's identity — it likely
  warrants its own design doc once the component base exists.
