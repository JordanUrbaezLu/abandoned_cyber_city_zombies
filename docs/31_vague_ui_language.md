# 31 — Vague UI Language (hide magnitudes in-game; exact numbers live in docs)

**Status:** IMPLEMENTED 2026-06-22 (`-GscOnly`), then simplified in the follow-up sweeps (see §8). The vague
wording is LIVE in `acc_hud.lua` (the `AccPerkCards` table + the OC/Exo report cards) and the GSC toasts.
This doc is an **INDEX**, not a value store: it maps the in-game vague text to the *system* that owns the exact
number. Tune balance from the **per-system docs** (and the code); read `ui/uieditor/menus/hud/acc_hud.lua` for the
**final shipped wording** (it is simpler/shorter than the design-intent tables below — see §8).

## 1. Goal & principle

Players should feel an upgrade is **better** without knowing **by how much** — qualitative "feel", not a spreadsheet.
User's canonical example: *"Regen starts 20% sooner"* → *"Regen starts sooner"*; the Mega → *"Regen starts even sooner"*.

**Principle:** show **direction + relative strength**, hide **magnitude**.
- The EXACT numbers live in the **per-system docs** + the code. In-game text is vague. Docs are the balance source-of-truth.
- **Preserve base < Mega (and tier) ordering** via a word ladder, so the player still grasps that Mega / a higher tier is
  stronger — just not the number.

## 2. Vague vocabulary (standardized ladders — use ONLY these)

| Magnitude class | Base / lower tier | Mega / higher tier | Top (PaP III / large) |
|---|---|---|---|
| Generic increase (damage, ammo, explosive) | `more` | `even more` / `much more` | `greatly increased` |
| Toughness (HP / survivability) | `tougher` | `even tougher` | — |
| Speed (move, fire rate, reload) | `faster` | `even faster` | — |
| Rate of fire (when named) | `higher rate of fire` | `even higher rate of fire` | — |
| Timing / onset | `sooner` | `even sooner` | — |
| Duration | `longer` | `even longer` | — |
| Reduction (recoil, damage taken) | `reduced` / `less` | `greatly reduced` / `much less` | — |
| Discount | `cheaper` | — | — |
| Per-tier scaling (overclock, exo) | `grows each tier` | — | — |

**PaP damage ladder (lockstep on ALL surfaces — `acc_hud.lua` AND `_acc_pap_levels.gsc`):**
T1 = `more damage`, T2 = `much more damage`, T3 = `greatly increased damage` (shipped card wording is shorter still:
`T1: more damage` / `T2: much more damage` / `T3: max damage`, `acc_hud.lua:110-111`).

## 3. KEEP policy (numbers that STAY — NOT "how much a stat increases")

Keep = a **price**, a **tier/progress indicator**, a **currency/inventory count**, a **reaction-critical live timer**, or a
**pure mechanic**. These tell you *what / where / what you own / what it costs*, never *how much a stat grows*.

- **Prices** — Points (PaP 5000/7500/10000, `acc_hud.lua:52-54`; perks 2000/2500/3000/3500/4000, `AccPerkCards`
  `acc_hud.lua:66-111`) + Data Shards (exo = 4×tier: 4/8/12/16/20 … up to 40 at tier 10, `AccExoCosts`
  `acc_hud.lua:128`; overclock tier costs; Neural slot; altar; reactor). (Cyberware node/respec prices are
  NOT a live surface — the tree is disabled by default, `_acc_cyberware.gsc:96` gate `acc_cyberware_on 0`; the
  live weapon-upgrade spend is the Overclock terminal.)
- **Tier / progress** — PaP `Tier N/3` + `T1/T2/T3` + roman `I/II/III` icon; Overclock `vN/10` (`acc_hud.lua:212`);
  Exo `Tier N/10` + `layer N` (`acc_hud.lua:244`, `ACC_EXO_MAX 10` at `_acc_exo.gsc:29`); Reactor `wave N/M`.
- **Currency / inventory counts** — `DATA SHARDS N`, `MEGA BOTTLES N`, `WEB GRENADES N`, `+N` grants, Neural `+1 slot`.
- **Reaction timers** — Decon `SEALS IN 10/5 SECONDS`, ability cooldown `Ns left`, cache `refills next round`.
- **Pure mechanics** — carry 3rd weapon, solo self-revive, one-hit melee, PhD immunities, "Immune to boss abilities",
  "upgraded form / explosive / akimbo", powerup names, node/boss names.
- **Progress bars with no drawn number** — round/HOSTILES bar, boss HP bar, NITRO charge, the HP color bar itself.
- **Dev-only** — crosshair floating damage number (gated on `level.acc_dev`, never ships → no edit; see D2).

## 4. The exact → vague mapping (DESIGN INTENT — shipped wording is in `acc_hud.lua`, see §8)

This section records the *intent*: for each surface, the real value it hides and the direction word it shows. The
**shipped** strings are simpler/shorter than the "Vague" column here (the simplification sweep in §8); when they
disagree, `acc_hud.lua` (and the GSC toasts) is the truth for wording, the per-system doc is the truth for values.

### 4a. Perk cards — `AccPerkCards` in `ui/uieditor/menus/hud/acc_hud.lua:66-112`  (exact values: `docs/10_perks.md`)

Cards live in one `AccPerkCards` table (index = `_acc_perk_info::perk_card_index`), each with `base` / `mega` /
`megaFull` bullet lists — NOT per-benefit lines. Design intent per perk:

| Perk / card idx | Exact (design) | Vague (intent) → shipped bullet |
|---|---|---|
| JUGG base `[1]` | `250 HP - down on the 6th hit` | tougher → `Take more hits` |
| JUGG Mega `[1]` | `300 HP - down on the 7th hit` | even tougher → `Take even more hits` |
| QUICK REVIVE base `[2]` | `Revive in 2.0s` / `Regen starts 20% sooner` / solo self-revive | faster / sooner → `Revive allies faster` / `Health regen starts sooner` / `Revive yourself solo` |
| QR Mega `[2]` | `Revive in 1.0s` / `Regen starts 40% sooner` / `+15% speed near a downed ally` | even faster / even sooner → `Revive even faster` / `Regen starts even sooner` / `Faster near allies` |
| SPEED COLA base `[3]` | `+50% reload speed` | faster → `Reload faster` |
| SPEED COLA Mega `[3]` | `+75% reload speed` | even faster → `Reload even faster` |
| DOUBLE TAP base `[4]` | `2 bullets/shot (~1.6× DPS)` / `+33% rate of fire` | extra bullet / higher RoF → `Fires extra bullets` / `Shoots faster` |
| DOUBLE TAP Mega `[4]` | extra-bullet temper 0.6×→0.8× (~2.1× DPS) | hit harder → `Extra bullets hit harder` |
| STAMIN-UP base `[5]` | `~12s sprint` / `+7-8% move speed` | longer / faster → `Sprint longer` / `Move faster` |
| STAMIN-UP Mega `[5]` | `+15% move speed` | even faster → `Move even faster` |
| MULE KICK base `[6]` | carry 3rd gun | mechanic → `Carry an extra gun` |
| MULE KICK Mega `[6]` | `+20% reserve ammo/round` / `all buys 10% cheaper` | more / cheaper → `More ammo each round` / `Cheaper buys` |
| DEADSHOT base `[7]` | `+1.4 headshot dmg` / aim-assist to head | more → `More headshot damage` / `Aims at the head` |
| DEADSHOT Mega `[7]` | `+1.6 headshot dmg` / `-50% recoil` | even more / greatly reduced → `Even more headshot dmg` / `Much less recoil` |
| WIDOW base `[8]` | web trap 16s (slow 12s) / restock 2/round | mechanic → `Grenades trap zombies` / `Webbing on melee` / `Refills each round` |
| WIDOW Mega `[8]` | pool 6 / restock 4/round | more → `Scuttle fast when low` / `More spider drops` |
| PHD base `[9]` | fall/blast immunity / explode-when-downed | mechanic → `No fall or blast damage` / `Explode when downed` |
| PHD Mega `[9]` | `+20% explosive dmg` / `+20% move speed` / slide-to-explode | more / faster → `Slide to explode` / `Bigger explosions` / `Move faster` |
| ELECTRIC CHERRY `[10]` | reload-zap (scales with empty mag) | mechanic → `Reload to zap zombies` / `Emptier mag = bigger zap` (+ Mega `Stronger, faster zap` / `Shrugs off boss zaps`) |

### 4b. Pack-a-Punch  (exact: `docs/04_weapons.md`)

| Surface | location | Exact | Vague / shipped |
|---|---|---|---|
| PaP card `[11]` bullets | `acc_hud.lua:110-111` | `T1 +33% / T2 +100%+UPGRADE / T3 +150% MAX` | `T1: more damage` / `T2: much more damage` / `T3: max damage` |
| `pap_tier_benefit(1/2/3)` | `acc_hud.lua:45-49` | `+33% / +100%+form / +150% MAX` | `more damage` / `much more + new form` / `max damage` |
| next-tier line (render) | `acc_hud.lua:307,327` | — | `Max weapon damage` / `pap_tier_benefit(nextTier)` |
| `tier_benefit(1/2/3)` (GSC) | `_acc_pap_levels.gsc:1497-1499` | `+33% / +100%+form / +150% MAX` | `more damage …` / `much more damage + upgraded form …` / `greatly increased damage (MAX)` — **currently unused** (no callers; the toast that showed it was removed, see below) |

The old **PaP tier/benefit TOAST is REMOVED** (`_acc_pap_levels.gsc:732`, user 2026-06-22): a pack shows only the
machine price, no benefit popup — so there is no magnitude to hide there anymore. This also left the GSC
`tier_benefit()` helper (`:1492`) with no callers — it is dead code that renders nowhere.

⚠️ **Duplicated text (kept in lockstep by convention):** the PaP ladder lives in `acc_hud.lua` (`pap_tier_benefit`
+ the `AccPerkCards[11]` bullets — the ONLY live surface) and is mirrored in `_acc_pap_levels.gsc` (`tier_benefit`,
per the `acc_hud.lua:42` mirror note). The GSC copy is **currently dead code** (no callers; its toast was removed,
above), so it renders nowhere today — but keep the two in sync so a re-enabled toast can never disagree.

### 4c. Overclock & Exo report cards — `acc_hud.lua`  (exact: `docs/04_weapons.md`, `docs/29_exo_suit_plan.md`)

Both cards already ship the vague wording; the tier readout (`vN/10`, `Tier N/10`) is the only number shown.

| Surface | line | Exact | Shipped vague |
|---|---|---|---|
| OC dmg/tier | `acc_hud.lua:220` | `+<tier*5>% weapon damage` | `More gun damage` |
| OC glitch dmg | `acc_hud.lua:221` | `+<tier*25>% vs glitch zombies` | `More vs glitch zombies` |
| OC ammo-back | `acc_hud.lua:222` | `<tier*10>% ammo back on headshot KILL` | `Headshot kills give ammo` |
| Exo resist | `acc_hud.lua:254,262` | `-<tier*6>% damage taken` (6%/tier, clamped -80%, user 2026-07-08) | `Take less damage` |
| Exo melee | `acc_hud.lua:255,263` | `+<tier*30>% knife / melee damage` | `Stronger melee` |
| Exo depth/next-tier | `acc_hud.lua:261,269` | `Full speed to layer N` + next-tier Data-Shard cost | shows `layer N` (kept) + shard price |

Note: the abyss only has 5 built layers, so the exo card caps the "full speed to layer N" text at 5 even though tiers
6-10 keep adding resist + melee (`acc_hud.lua:257-260`).

### 4d. GSC messages (already vagued)

| Surface | file:line | Exact | Shipped vague |
|---|---|---|---|
| Exo tier-up toast | `_acc_exo.gsc:157-158` | `Tier N/10, -<N*6>% dmg taken, +<N*30>% melee` | `Tier N/10 - faster, tougher, stronger melee` (keeps `Tier N/10`) |
| Stabilizer toast | `_acc_weapon_abilities.gsc:293` | `Stabilizer: 5s recoil/fire-rate boost` | `Stabilizer: recoil boost` |
| EMP lockout | `_acc_elites.gsc:902` | `Cyberware locked for <N>s` (`ACC_ELITE_EMP_HIT_DISABLE_SEC 5`) | `EMP surge! Cyberware locked for Ns` — **KEPT** (§5 D3: a recovery timer, not a benefit). NB: the EMP elite class was removed 2026-06-22 (`_acc_elites.gsc:215-216`), so this string rarely fires. |

## 5. DECISIONS (RESOLVED, user 2026-06-22)

- **D1 — Player HP readout `cur / max`** → **DROPPED.** The numeric readout is removed from `_acc_health_bars.gsc`
  (`:258`); the color HP bar is the only health cue now. Killed the biggest magnitude leak.
- **D2 — Crosshair damage number** → **left as-is** (dev-only, `level.acc_dev`, never ships).
- **D3 — Debuff durations** (EMP lockout `Ns`) → **KEPT** (it's a debuff recovery timer, not a benefit magnitude).
- **D4 — `layer N` / "1 layer deeper" (Exo)** → **KEPT** (a depth/tier position indicator).
- **D5 — `(-10%)` discount label** → **vagued to `(Armory)`** (`acc_hud.lua:315,355`); the discounted price stays real.
- **D6 — Tier indicators** (`Tier N/10`, `vN/10`, `PaP I/II/III`, `T1/T2/T3`) → **KEPT** (progress, not magnitude).
- **D7 — Usability floor** → **keep relative-intensity hints.** Info-heavy lines retain a relative word so players
  sense scale without a number.

## 6. Docs coverage (exact values live per-system, not here)

Vague the UI only where the exact value is documented. Coverage: perk base/Mega (`docs/10_perks.md`), PaP ladder
(`docs/04_weapons.md`), overclock per-tier (`docs/04_weapons.md`), exo per-tier (`docs/29_exo_suit_plan.md`), boss
items (`docs/09_boss_items.md`), Stabilizer (`docs/04_weapons.md`).

## 7. Implementation notes

- All edits are `.lua` rawfile + `.gsc` string literals → **`-GscOnly`** build path (no geometry / LED). LUI string-only
  changes are syntax-safe but **launch-test once** (LUI runtime errors only show in-game as `UI Error <code>`).
- Keep the PaP ladder + duplicated literals (§4b ⚠️) in lockstep.
- Any card-bullet edit must pass the length check (§8) before shipping.

## 8. Refinements (2026-06-22, post-implementation)

Two follow-up user rules + two misses caught by the per-perk audit (`audit-perk-numbers` workflow):
- **SHORT bullets — hard rule.** Card bullets MUST be **≤ ~28 chars** or they WRAP and break the card layout (the
  text area is ~30 chars: 372px card, scale-0.85 text from x=44, `acc_hud.lua:178,190`). Double Tap was the worst
  offender. A length check (node, scans the `AccPerkCards` arrays + the OC/exo card lines) must pass before shipping.
- **SIMPLE language.** Plain, instantly-understood wording, not clever phrasing. The §4 "Vague" column is the
  *design intent*; the SHIPPED strings are simpler/shorter (e.g. Jugg `Take more hits`; Double Tap `Fires extra
  bullets` / `Shoots faster`; Mule Kick `Carry an extra gun`; PaP `T1: more damage … T3: max damage`). **Read
  `acc_hud.lua` for the final shipped wording; read the per-system doc for the exact VALUE.**
- **Miss 1 (per-perk audit):** a *second* discount line (`acc_hud.lua` perk-buy `sub`) still showed `(-10%)` → now
  `(Armory)` (`acc_hud.lua:355`).
- **Miss 2 (re-sweep):** the **exo upgrade toast** (`_acc_exo.gsc`) still printed `-N% dmg, +N% melee` (the vague pass
  missed it — exo isn't a perk) → now `faster, tougher, stronger melee` (`_acc_exo.gsc:158`).
- Per-perk audit verdict: all perks clean after these fixes; remaining digits are prices/tiers/counts/timers, code
  comments, `#define`s, or debug-gated strings (never shown in normal play).
