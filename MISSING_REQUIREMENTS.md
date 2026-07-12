# Missing Requirements — the short list of what is still open, and why

> **The map is FULLY BUILT.** First clean compile + link landed 2026-06-12; the
> Windows dev box has Mod Tools installed (setup complete 2026-07-03) and agents
> build headlessly with `.\tools\build_map.ps1`. ~48 active `_acc_*` modules run
> from `_acc_main.gsc` init(). This file is **no longer** the "nothing is
> verified yet" tracker it started as — it is now a small punch-list of items
> still genuinely open in the code.
>
> **Live status lives elsewhere:** the per-requirement tracker is
> [docs/15_requirements_checklist.md](docs/15_requirements_checklist.md) (its
> per-item statuses are a frozen 2026-06-12 snapshot — read its "Current-state
> corrections" header, then [CHANGELOG.md](CHANGELOG.md) for what actually
> shipped). Don't restate a checklist total here; it goes stale the day it's
> written.

---

## Still-open items (confirmed against code, 2026-07-10)

- **Self-revive purchase module — not built.** Cyberware **Caching** already sets
  the discount flag `self.acc_cw_selfrevive_shard_discount = 0.5`
  (`_acc_cyberware.gsc:549`), but the comment there (`:546-547`) states it is
  "consumed by the future self-revive module" — that module does not exist yet.
  Design intent: docs/05_mechanics.md.

- **Ghost Protocol also cloaks elites and bosses.** Cyberware Ghost Protocol uses
  the stock refcounted `ignoreme` pipeline (`_acc_cyberware.gsc:757/763`), which
  is **global** to zombie targeting — and our elites/bosses are promoted stock
  zombies, so they untarget a cloaked player too. Restoring elite/boss aggro
  needs a custom favoriteenemy/targeting pass on the elite side. Deferred to
  balance work; documented in-code at `_acc_cyberware.gsc:695-699`.

- **EMP-elite ability-lock is set but not consumed.** The EMP elite writes
  `player.acc_cw_locked_until` (`_acc_elites.gsc:900`), but nothing in the
  Cyberware watchers reads it yet, so a hit doesn't actually gate ability
  activation. Wire the gate check into the cyberware ability paths.

- **Opt-in modifiers have no config UI.** All 11 modifiers
  (`_acc_modifiers.gsc:61-73`: code_red, limited_liability, fragility, bleed_out,
  draft_mode, shardless, one_shot, roguelike_lite, express, sprint,
  shortened_rounds) toggle via `acc_mod_<name>` dvars and most drive real effects
  in `apply_global_modifiers()`. What's still open is only the
  `TODO(acc-config)` at `:56` — parsing a config file / UI struct instead of raw
  dvars. Design reference: docs/06_replayability.md.

- **A few engine-property ability halves still need GDT variants.** GSC has no
  runtime setter for recoil / fire-rate / burst pattern / grenade fuse, so these
  need authored weapon-override GDTs (Mod Tools are installed — this is unblocked
  GDT work, just not done):
  - Slug Round's tighter-cone / longer-range half (the 3× single-target damage
    half is live in `_acc_weapon_abilities.gsc` + `_acc_damage.gsc`; note at
    `_acc_weapon_abilities.gsc:20`).
  - Triple Tap's burst reshape and Extended Fuse's airburst
    (`effect_triple_tap` / `effect_extended_fuse` are defined but unreachable —
    `_acc_weapon_abilities.gsc:21-24`).

- **Latent map bug — 7 malformed `reflection_probe` boxes.** Verified in
  `map_source/zm/zm_abandoned_cyber_city.map` (2026-07-10): 7 of the 15
  reflection probes have an inverted Y extent (`size_min Y 548.5 > size_max Y
  544.75`). Harmless to the bake but the boxes don't bound what they should;
  resize `size_min ≤ size_max` on each axis, then rebuild WITH the LED bake to
  confirm. (Salvaged from the retired lab-tunnel LED research doc before it was
  deleted — that was the only place this was written down.)

## Out of scope by design (REQUIREMENTS.md "Out of Scope v1.0")

Main-quest Easter Egg, persistent meta-progression, extra game modes — not
missing, deliberately excluded. See REQUIREMENTS.md for the current list.
