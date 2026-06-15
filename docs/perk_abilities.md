# Perk Abilities — Full List

What every perk in `zm_abandoned_cyber_city` does — base tier and Mega tier, one bullet per effect. Companion to the design spec [13_perks.md](13_perks.md) (source of truth for numbers and stacking).

**`(BASE)`** = stock *Black Ops III* behavior inherited from the vanilla game. Untagged bullets are custom to this map (new or retuned). Mega tiers are all map-specific, so no Mega bullet is `(BASE)`. Deadshot and Aura Blast are custom perks, so they carry no `(BASE)` bullets.

## Map-wide perk rules

- **9 perks total** — 7 stock BO3 perks (retuned) + 2 custom (Deadshot, Aura Blast *(WIP — not on the map yet)*). 8 are live on the map today.
- **No 4-perk cap.** A single player can own and stack **all 9** perks at once if they can afford them.
- **Where to buy:** all perks are at the **Lab** (4 machines that re-roll to a random 4-of-9 each round). Perks cost **Points**.
- **Mega tiers are not bought with Points.** Each base perk has a **Mega** upgrade unlocked by spending **1 Empty Mega Bottle** (dropped on every boss kill) at a Lab machine while you own the base perk and it is in rotation. Mega is **sticky for the run** (survives death/re-buy).
- **Player HP baseline:** no perk = **100 HP**, down on the **3rd** regular zombie melee hit.
- Buying all 9 base perks = **26,500 Points**.

---

## 1. Jugger-Nog — 4,000 Points

**Base abilities:**
- Raises max health to **250 HP** (no-perk base is **100 HP**). **(BASE)**
- Survive **5** regular zombie melee hits — **down on the 6th** (no perk: down on the 3rd).

**Mega — Ultimate Tank:**
- Raises max health to **314 HP** — survive **6** hits, **down on the 7th**.
- **Immune to boss abilities** — scripted Subroutine Core disables (power-off, perks-off, boss-phase stun fields) do not affect you.

**Hit counts** (at ~45 damage per zombie melee hit): **100 HP → down on 3rd · 250 HP → down on 6th · 314 HP → down on 7th**. ("Down on the Nth hit" = you survive N−1 hits; the Nth drops you into last-stand.)

---

## 2. Quick Revive — 2,500 Points

**Base abilities:**
- **Revive teammates in 2.0 s** (vs 3.0 s with no perk).
- **HP regen starts 15% sooner** after you take damage — begins at **2.04 s** instead of the **2.4 s** baseline (earlier start, same heal rate).
- **Solo self-revive.** **(BASE)**

**Mega — Savior:**
- **Revive teammates in 1.0 s** (half of base QR's 2.0 s).
- **HP regen starts 30% sooner** — begins at **1.68 s** instead of 2.4 s.
- **+15% move speed** (×1.15) while any *other* player is downed / bleeding out (clears the moment nobody is down; your own down does not count). Multiplicative with other speed buffs.

---

## 3. Speed Cola — 3,500 Points

**Base abilities:**
- **+50% reload speed.** **(BASE)**
- **Faster barrier board / repair animation.** **(BASE)**

**Mega — Sleight of Hand Expert:**
- **+70% reload speed** (replaces the base +50%).

> *Faster perk-drink animation was cut (2026-06-14): the drink anim is shared map-wide
> with no per-perk lever, so it can't be gated to Speed Cola owners.*

---

## 4. Double Tap 1.0 — 2,000 Points

*Rate of fire only — the original Double Tap, not the 2.0 double-bullet version.*

> **⚠️ Migration pending (flagged 2026-06-14):** the base perk is **currently the stock
> Double Tap 2.0** machine (`specialty_doubletap2`, which fires an extra bullet — not pure
> rate-of-fire). The **+33% rate-of-fire-only** profile below and the "Double Tap 1.0" name
> on the card are the **migration target**, not the shipped base. TODO: convert the base to a
> true Double Tap **1.0** (strip the 2.0 extra-bullet so it is rate-only) and verify the +33%.
> The Mega (Gun Slinger) +50% rate / −75% swap ARE already implemented via the `fastfire`
> weapon-variant twin.

**Base abilities:**
- **+33% rate of fire.** **(BASE)**

**Mega — Gun Slinger:**
- **+50% rate of fire.**
- **Weapon-swap time reduced 75%** (≈4× faster weapon swaps).

---

## 5. Stamin-Up — 2,000 Points

**Base abilities:**
- **Longer sprint** — sprint lasts **~12 s** (vs ~4 s with no perk). **(BASE)**
- **Stamina refills in ~4 s** after it depletes. **(BASE)**
- **+7–8% movement speed**; overall mobility caps around **~109%**. **(BASE)**
- Sprint is still **finite** — not unlimited. **(BASE)**

**Mega — The Flash:**
- **+15% sprint speed** (×1.15) — applied to all movement (BO3 has no sprint-only speed lever).

---

## 6. Mule Kick — 2,500 Points

**Base abilities:**
- **Third primary weapon slot** (carry 3 primaries instead of 2). **(BASE)**

**Mega — The Armory:**
- **+25% ammo capacity** per weapon (reserve ammo).
- **All buys 10% cheaper** — every point purchase (wallbuys, ammo, perks, Pack-a-Punch, Mystery Box) costs 10% less while you hold The Armory.

---

## 7. Deadshot — 3,500 Points *(custom — not a stock BO3 perk, so no `(BASE)` tags)*

> **Map recoil baseline:** every gun kicks at **2.5× vanilla recoil** by default (a map-wide
> skill rule, not a perk). Deadshot's reductions are measured **off that 2.5× baseline**.

**Base abilities:**
- **×1.5 headshot damage.**
- **−35% weapon recoil** → 2.5 × 0.65 = **1.625× vanilla** (still above stock).
- **Snaps to the nearest head while aiming down sights** (not on bosses).

**Mega — American Sniper:**
- **×2 headshot damage** (replaces the base ×1.5).
- **−70% weapon recoil** → 2.5 × 0.30 = **0.75× vanilla** (now *below* stock — a real reward).

**Effective headshot damage** (Deadshot stacks with the map's ×2 trash / ×3 boss headshot multiplier): base ≈ **×3.0** on trash / **×4.5** on bosses; American Sniper ≈ **×4.0** / **×6.0**.

---

## 8. Widow's Wine — 4,000 Points

**Base abilities:**
- **Widow's Wine grenades** (replace your lethal grenade) — sticky, Semtex-like; zombies caught in the blast but not killed are webbed: those closest (≤100u) are **frozen for 16 s**, farther ones (≤256u) **slowed for 12 s** (stock `WIDOWS_WINE_COCOON_DURATION` 16.0 / `_SLOW_DURATION` 12.0 — unchanged). **(BASE)**
- **Self-defense webbing** — when a zombie melees you, you release a burst of webbing that webs nearby zombies (**16 s** frozen / **12 s** slowed). **(BASE)**
- **Webbing melee** — meleeing a zombie coats it in webbing and slows it. **(BASE)**
- **Web grenades restock 2 at the start of each round** (also refill on Max Ammo and from blue spider-drop pickups). **(BASE)**

**Mega — Spiderman:**
- **Hold up to 6 web grenades.**
- **Restock 4 web grenades each round** (instead of 2).

---

## 9. Aura Blast — 2,500 Points *(custom — not a stock BO3 perk, so no `(BASE)` tags)*

> **🚧 WIP — on hold, not on the map yet.** The abilities below are the planned design only.

**Base abilities:**
- Activated by a **crouch + melee** chord.
- Releases a **400-unit radius shockwave.**
- **3-second stun** (duration depends on enemy type — see below).
- **120-second cooldown.**
- Per-enemy-type effect:
  - **Regular zombies:** full stun.
  - **Shielded elites:** shield knocked down for the stun.
  - **Teleporter elites:** cannot teleport.
  - **EMP elites:** 1-second stun.
  - **Mini-boss:** 50% duration (~1.5 s).
  - **Full boss:** immune.

**Mega — Mega Man:**
- **800-unit radius shockwave.**
- **60-second cooldown.**
- **2 charges.**
- **Bosses can be affected** — reduced effect vs. trash (~1.5 s / interrupt-only) so the fight isn't trivialized.
