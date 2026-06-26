# docs/50 — Vague UI Language (hide magnitudes in-game; exact numbers live in docs)

**Status:** IMPLEMENTED 2026-06-22 (`-GscOnly`). Survey done via the `survey-ui-numbers` workflow (133 in-game strings
across `acc_hud.lua` + 14 `_acc_*.gsc`). All §5 decisions ruled (see §5). This doc is the SoT linking the vague in-game
text to the exact values; tune balance from the exact numbers here + the per-system docs, NOT the in-game wording.

## 1. Goal & principle

Players should feel an upgrade is **better** without knowing **by how much** — qualitative "feel", not a spreadsheet.
User's canonical example: *"Regen starts 20% sooner"* → *"Regen starts sooner"*; the Mega → *"Regen starts even sooner"*.

**Principle:** show **direction + relative strength**, hide **magnitude**.
- The EXACT numbers move to / stay in the **docs** (this file is the index; per-system docs hold the values). In-game text
  becomes vague. Docs are the balance source-of-truth.
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
T1 = `more damage`, T2 = `much more damage`, T3 = `greatly increased damage`.

## 3. KEEP policy (numbers that STAY — NOT "how much a stat increases")

Keep = a **price**, a **tier/progress indicator**, a **currency/inventory count**, a **reaction-critical live timer**, or a
**pure mechanic**. These tell you *what / where / what you own / what it costs*, never *how much a stat grows*.

- **Prices** — Points (PaP 5000/7500/10000; perks 4000/2500/3500/5000/2000) + Data Shards (exo 5/10/15/20/25; overclock
  tier costs; cyberware respec; Neural slot; altar; reactor).
- **Tier / progress** — PaP `Tier N/3` + `T1/T2/T3` + roman `I/II/III` icon; Overclock `vN/5`; Exo `Tier N/5` + `layer N`;
  Reactor `wave N/M`.
- **Currency / inventory counts** — `DATA SHARDS N`, `MEGA BOTTLES N`, `WEB GRENADES N`, `+N` grants, Neural `+1 slot`.
- **Reaction timers** — Decon `SEALS IN 10/5 SECONDS`, ability cooldown `Ns left`, cache `refills next round`.
- **Pure mechanics** — carry 3rd weapon, solo self-revive, one-hit melee, PhD immunities, "Immune to boss abilities",
  "upgraded form / explosive / akimbo", "new camo", powerup names, node/boss names.
- **Progress bars with no drawn number** — round/HOSTILES bar, boss HP bar, NITRO charge, the HP color bar itself.
- **Dev-only** — crosshair floating damage number (gated on `level.acc_dev`, never ships → no edit; see D2).

## 4. The exact → vague mapping (this section IS the source of truth)

Every row: in-game gets the **Vague** text; the **Exact** column is the real value (kept here + in the named doc).

### 4a. Perk cards — `ui/uieditor/menus/hud/acc_hud.lua`  (exact values: `docs/perk_abilities.md`, `docs/13_perks.md`)

| Perk / tier | line | Exact (current) | Vague |
|---|---|---|---|
| JUGG base | 66 | `250 HP - down on the 6th hit` | `Much tougher - takes more hits to go down` |
| JUGG base (no-perk ref) | 66 | `(no perk: 100 HP / 3rd hit)` | `(no perk: goes down fast)` |
| JUGG Mega (mega+megaFull) | 67-68 | `300 HP - down on the 7th hit` | `Even tougher - survives even more hits` |
| QUICK REVIVE base | 70 | `Revive teammates in 2.0s` | `Revive teammates faster` |
| QR base | 70 | `Regen starts 20% sooner` | `Regen starts sooner` |
| QR Mega revive | 71/72 | `Revive in 1.0s` | `Revive even faster` |
| QR Mega regen | 71/72 | `Regen starts 40% sooner` | `Regen starts even sooner` |
| QR Mega speed | 71/72 | `+15% speed near a downed ally` | `Move faster near a downed ally` |
| SPEED COLA base | 74 | `+50% reload speed` | `Faster reload` |
| SPEED COLA Mega | 75/76 | `+75% reload speed` | `Even faster reload` |
| DOUBLE TAP base | 78 | `2 bullets/shot, each 0.6× → ~1.6× DPS` | `Fires an extra bullet per shot (much more damage)` |
| DOUBLE TAP base | 78 | `+33% rate of fire` | `Higher rate of fire` |
| DOUBLE TAP Mega | 79/80 | `+45% rate of fire` | `Even higher rate of fire` |
| STAMIN-UP base | 82 | `Longer sprint (~12s)` | `Longer sprint` |
| STAMIN-UP base | 82 | `+7-8% movement speed` | `Faster movement` |
| STAMIN-UP Mega | 83/84 | `+15% movement speed` | `Even faster movement` |
| MULE KICK Mega | 87/88 | `+20% reserve ammo each round` | `More reserve ammo each round` |
| MULE KICK Mega | 87/88 | `All buys 10% cheaper` | `All buys cheaper` |
| DEADSHOT base | 90 | `+1.4 headshot dmg bonus` | `Bonus headshot damage` |
| DEADSHOT Mega | 91/92 | `+1.6 headshot dmg bonus` | `Even more bonus headshot damage` |
| DEADSHOT Mega | 91/92 | `-50% weapon recoil` | `Greatly reduced weapon recoil` |
| WIDOW base | 94/96 | `Web grenades trap zombies 16s (slow 12s)` | `Web grenades trap zombies for a while (then slow them)` |
| WIDOW base | 94 | `Restock 2 web nades / round` | `Restock web nades each round` |
| WIDOW Mega | 95/96 | `6 web grenades (virtual pool)` | `Larger web-grenade pool` |
| WIDOW Mega | 95/96 | `Restock 4 / round (vs 2)` | `Restock even more each round` |
| PHD Mega | 99/100 | `+20% move speed` | `Faster movement` |
| PHD Mega | 99/100 | `+20% explosive dmg` | `More explosive damage` |

### 4b. Pack-a-Punch — `acc_hud.lua` (idx-10 array + `pap_tier_benefit`) + `_acc_pap_levels.gsc`  (exact: `docs/05_weapons.md`)

| Surface | line | Exact | Vague |
|---|---|---|---|
| idx-10 T1 | 102 | `T1: +50% damage + camo (5000)` | `T1: more damage + camo (5000)` |
| idx-10 T2 | 103 | `T2: +100% damage + UPGRADE (7500)` | `T2: much more damage + UPGRADE (7500)` |
| idx-10 T3 | 103 | `T3: +150% damage MAX (10000)` | `T3: greatly increased damage MAX (10000)` |
| `pap_tier_benefit(1)` | 46 | `+50% damage + new camo` | `more damage + new camo` |
| `pap_tier_benefit(2)` | 47 | `+100% damage + upgraded form` | `much more damage + upgraded form` |
| `pap_tier_benefit(3)` + MAX branch | 48, 298 | `+150% weapon damage (MAX)` | `greatly increased weapon damage (MAX)` |
| PaP GSC toast T1/T2/T3 | `_acc_pap_levels.gsc:721-723` | `+50/+100/+150pct` | `more / much more / greatly increased` |

⚠️ **Load-bearing duplication:** lines 48 & 298 are the same literal; the PaP ladder appears in BOTH `acc_hud.lua` and
`_acc_pap_levels.gsc`. All must change together or surfaces disagree.

### 4c. Overclock & Exo report cards — `acc_hud.lua`  (exact: `docs/05_weapons.md`, `docs/47_exo_suit_plan.md`)

| Surface | line | Exact | Vague |
|---|---|---|---|
| OC dmg/tier | 215 | `+<tier*5>% weapon damage (always on)` | `More weapon damage - grows each tier (always on)` |
| OC glitch dmg | 216 | `+<tier*25>% damage vs glitch zombies` | `More damage vs glitch zombies - grows each tier` |
| OC ammo-back | 217 | `<tier*10>% ammo back on a headshot KILL` | `Ammo back on a headshot KILL - grows each tier` |
| Exo resist (active + T0) | 249/253 | `-<tier*5>% damage taken` | `Less damage taken (grows each tier)` |
| Exo melee (active + T0) | 250/254 | `+<tier*30>% knife / melee damage` | `More knife / melee damage (grows each tier)` |
| Exo next-tier line | 261 | `-> layer N, -X% dmg, +Y% melee` | `-> layer N, less dmg taken, more melee` (keep `layer N`) |

### 4d. GSC messages

| Surface | file:line | Exact | Vague |
|---|---|---|---|
| Exo tier-up toast | `_acc_exo.gsc:141-143` | `..., -<N*5>% dmg taken, +<N*30>% melee` | `..., ^5less^7 dmg taken, ^5stronger^7 melee (grows each tier)` (keep `Tier N/5` + `layer N`) |
| Stabilizer toast | `_acc_weapon_abilities.gsc:289` | `Stabilizer: 5s recoil/fire-rate boost` | `Stabilizer: recoil/fire-rate boost` |
| EMP lockout | `_acc_elites.gsc:355` | `Cyberware locked for <N>s` | *pending D3* |

## 5. DECISIONS (RESOLVED, user 2026-06-22)

- **D1 — Player HP readout `cur / max`** → **DROPPED.** The numeric readout is removed from `_acc_health_bars.gsc`
  (creation + update both deleted); the color HP bar is the only health cue now. Killed the biggest magnitude leak.
- **D2 — Crosshair damage number** → **left as-is** (dev-only, `level.acc_dev`, never ships).
- **D3 — Debuff durations** (EMP lockout `Ns`) → **KEPT** (it's a debuff recovery timer, not a benefit magnitude).
- **D4 — `layer N` / "1 layer deeper" (Exo)** → **KEPT** (a depth/tier position indicator).
- **D5 — `(-10%)` discount label** → **vagued to `(Armory)`** (`acc_hud.lua`); the discounted price stays a real number.
- **D6 — Tier indicators** (`Tier N/5`, `vN`, `PaP I/II/III`, `T1/T2/T3`) → **KEPT** (progress, not magnitude).
- **D7 — Usability floor** → **keep relative-intensity hints.** The info-heavy lines retain a relative word (e.g.
  "Much larger web-grenade pool", Double Tap "(much more damage)") so players sense scale without a number.

## 6. Docs coverage (vague the UI only where the exact value is documented)

**Covered:** perk base/Mega (`perk_abilities.md`, `13_perks.md`), PaP ladder (`05_weapons.md`), overclock per-tier
(`05_weapons.md`), exo per-tier (`47_exo_suit_plan.md`), boss items (`12_boss_items.md`), Stabilizer (`05_weapons.md`).

**Gaps to fill BEFORE vagueing (add the exact value to a doc first):**
- **G1** — EMP lockout duration (`ACC_ELITE_EMP_HIT_DISABLE_SEC`) — not documented → `docs/11_enemies.md` (only if D3 = hide).
- **G2** — QR Mega `+15% near-downed speed` + PhD Mega `+20% move / +20% explosive` — spot-check in `perk_abilities.md`.
- **G3** — Double Tap `~2x dmg` multiplier (not just "2 bullets") — confirm in `perk_abilities.md`.
- **G4** — Widow web `16s/12s`, pool `6`, restock `2→4` — confirm all four in `perk_abilities.md`.
- **G5** — Stamin-Up sprint `~12s` duration — confirm in `perk_abilities.md`.

## 7. Implementation (after sign-off)

- All edits are `.lua` rawfile + `.gsc` string literals → **`-GscOnly`** build path (no geometry / LED). LUI string-only
  changes are syntax-safe but **launch-test once** (LUI runtime errors only show in-game as `UI Error <code>`).
- Order: (1) fill doc gaps G1–G5; (2) edit `acc_hud.lua` card tables + render branches; (3) edit the GSC toasts; (4) apply
  D1/D3/D5 per the user's ruling; (5) CHANGELOG + this doc updated in the same pass (CLAUDE.md hard constraint).
- Keep the PaP ladder + duplicated literals (§4b ⚠️) in lockstep.

## 8. Refinements (2026-06-22, post-implementation)

Two follow-up user rules + two misses caught by the per-perk audit (`audit-perk-numbers` workflow):
- **SHORT bullets — hard rule.** Card bullets MUST be **≤ ~28 chars** or they WRAP and break the card layout (the
  text area is ~30 chars: 372px card, scale-0.85 text from x=44). Double Tap was the worst offender. A length check
  (node, scans the `AccPerkCards` arrays + the OC/exo card lines) must pass before shipping a card edit.
- **SIMPLE language.** Plain, instantly-understood wording, not clever phrasing. The §4 mapping above shows the
  *design intent*; the SHIPPED strings are simpler/shorter (e.g. Jugg "Take more hits"; Double Tap "Fires extra
  bullets" / "Shoots faster"; Mule Kick "Carry an extra gun"; PaP "T1: more damage … T3: max damage"). The **Exact
  column stays the source of truth for VALUES** — read `acc_hud.lua` for the final shipped wording.
- **Miss 1 (per-perk audit):** a *second* discount line `acc_hud.lua` perk-buy `sub` still showed `(-10%)` (only the
  PaP one had been fixed) → now `(Armory)`.
- **Miss 2 (re-sweep):** the **exo upgrade toast** (`_acc_exo.gsc`) still printed `-N*5% dmg, +N*30% melee` (the vague
  pass missed it — exo isn't a perk so the per-perk audit didn't cover it) → now "faster, tougher, stronger melee".
- Per-perk audit verdict: all 9 perks clean after these fixes; remaining digits are prices/tiers/counts/timers,
  code comments, `#define`s, or debug-gated strings (never shown in normal play).
