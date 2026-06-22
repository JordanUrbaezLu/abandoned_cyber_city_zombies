# Perk Abilities — Full List

What every perk in `zm_abandoned_cyber_city` does — base tier and Mega tier, one bullet per effect. Companion to the design spec [13_perks.md](13_perks.md) (source of truth for numbers and stacking).

**`(BASE)`** = stock *Black Ops III* behavior inherited from the vanilla game. Untagged bullets are custom to this map (new or retuned). Mega tiers are all map-specific, so no Mega bullet is `(BASE)`. Deadshot and PhD Flopper are custom perks, so they carry no `(BASE)` bullets.

## Map-wide perk rules

- **9 perks total** — 7 stock BO3 perks (retuned) + 2 custom (Deadshot, PhD Flopper). All 9 are live on the map today.
- **Start at 4 perk slots; buy more with Data Shards (up to 9).** The base cap is `level.perk_purchase_limit = 4`; each extra slot is bought at the underground **Neural Expansion Bay** for an escalating shard cost (4/6/8/10/12), raising the per-player limit via the stock hook `level.get_player_perk_purchase_limit` (`acc_perks::acc_perk_slot_limit`). This is the marquee trench incentive — see [13_perks.md](13_perks.md) Perk-Slot Rule.
- **Where to buy:** all perks are at the **Lab** (4 machines that re-roll to a random 4-of-9 each round). Perks cost **Points**.
- **Mega tiers are not bought with Points.** Each base perk has a **Mega** upgrade unlocked by spending **1 Empty Mega Bottle** (dropped on every boss kill) at a Lab machine while you own the base perk and it is in rotation. Mega is **sticky for the run** (survives death/re-buy).
- **Player HP baseline:** no perk = **100 HP**, down on the **3rd** regular zombie melee hit.
- Buying all 9 base perks = **29,500 Points**.

---

## 1. Jugger-Nog — 4,000 Points

**Base abilities:**
- Raises max health to **250 HP** (no-perk base is **100 HP**). **(BASE)**
- Survive **5** regular zombie melee hits — **down on the 6th** (no perk: down on the 3rd).

**Mega — Ultimate Tank:**
- Raises max health to **300 HP** — survive **6** hits, **down on the 7th**.
- **Immune to boss abilities** — scripted Subroutine Core disables (power-off, perks-off, boss-phase stun fields) do not affect you.

**Hit counts** (at ~45 damage per zombie melee hit): **100 HP → down on 3rd · 250 HP → down on 6th · 300 HP → down on 7th**. ("Down on the Nth hit" = you survive N−1 hits; the Nth drops you into last-stand.)

---

## 2. Quick Revive — 2,500 Points

**Base abilities:**
- **Revive teammates in 2.0 s** (vs 3.0 s with no perk).
- **HP regen starts 20% sooner** after you take damage — begins at **1.92 s** instead of the **2.4 s** baseline (earlier start, same heal rate).
- **Solo self-revive.** **(BASE)**

**Mega — Savior:**
- **Revive teammates in 1.0 s** (half of base QR's 2.0 s).
- **HP regen starts 40% sooner** — begins at **1.44 s** instead of 2.4 s.
- **+15% move speed** (×1.15) while any *other* player is downed / bleeding out (clears the moment nobody is down; your own down does not count). Multiplicative with other speed buffs.

---

## 3. Speed Cola — 3,500 Points

**Base abilities:**
- **+50% reload speed.** **(BASE)**
- **Faster barrier board / repair animation.** **(BASE)**

**Mega — Sleight of Hand Expert:**
- **+75% reload speed** (replaces the base +50%).

> *Faster perk-drink animation was cut (2026-06-14): the drink anim is shared map-wide
> with no per-perk lever, so it can't be gated to Speed Cola owners.*

---

## 4. Double Tap 2.0 — 5,000 Points

*The full stock **Double Tap II Root Beer** — kept as-is. The extra bullet can't be disabled from a usermap, so we embrace it and balance around it.*

> **Design decision (2026-06-14):** the base perk IS the stock `specialty_doubletap2` machine,
> which fires an **extra bullet per shot** (≈2× damage). There is no usermap-side way to strip
> that, so we KEEP Double Tap **2.0** (not "1.0") and price/balance around what we have. It now
> costs **5,000** (vs ~2,000 for a rate-only perk) because doubling bullet output is a major
> damage perk. The Mega adds fire rate + faster swap via the `fastfire` weapon-variant twin.

**Base abilities (Double Tap 2.0):**
- **Fires 2 bullets per shot for the cost of 1 round of ammo** (double the pellets on shotguns) — effectively **~2× damage output**. **(BASE — stock 2.0)**
- **+33% rate of fire** (the stock Double Tap rate boost). **(BASE)**
- **Does NOT apply to** Wonder Weapons, the Ballistic Knife, or explosive weapons (stock 2.0 exclusion).

**Mega — Gun Slinger:**
- **+40% rate of fire** (on top of the 2.0 base; `fastfire` twin, fireTime ×0.714 — retuned from +50% on 2026-06-14).
- **Weapon-swap time reduced 50%** (≈2× faster weapon swaps).

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
- **+20% reserve ammo refilled at the start of every round**, per carried weapon (reworked 2026-06-16
  — was "+25% capacity"; a baked reserve cap can't be raised at runtime, so it's now a sustain refill
  instead. Also given instantly on acquire. Refill rate lowered 35% → 20% on 2026-06-21). Clamped to each gun's normal cap.
- **All buys 10% cheaper** — every point purchase (wallbuys, ammo, perks, Pack-a-Punch, Mystery Box) costs 10% less while you hold The Armory.

---

## 7. Deadshot — 3,500 Points *(custom — not a stock BO3 perk, so no `(BASE)` tags)*

> **Map recoil baseline:** the box guns kick at **1.75× vanilla recoil** by default (a map-wide
> skill rule, not a perk; lowered from 2.1× on 2026-06-16). Recoil reduction is **Mega-only** now —
> see American Sniper. Base Deadshot no longer changes recoil (the dropped layer that freed twin slots).

**Base abilities:**
- **+1.4 headshot damage bonus** (added into the headshot bonus sum, not multiplied — 2026-06-14).
- **Snaps to the nearest head while aiming down sights** (not on bosses).
- *(No recoil change — recoil reduction moved to the Mega tier 2026-06-16.)*

**Mega — American Sniper:**
- **+1.6 headshot damage bonus** (replaces the base +1.4 — no double dip; retuned 1.8→1.6 on 2026-06-16).
- **−50% weapon recoil** → 1.75 × 0.50 = **0.875× vanilla** (below stock — a genuinely steady gun).

**Effective headshot damage** — the bonuses are **summed**, then multiplied against the incoming damage (which already carries the gun's baked **`locHead`** hit-location mult). Map headshot bonus is now **+0.5 trash / +1.0 boss** (lowered from 2.0/2.0 on 2026-06-16). Effective head:body ratio = `locHead × (bonus sum)`. Most box guns are `locHead 5.0`, so a no-perk headshot ≈ **2.5× body (trash) / 5× body (boss)**; **Paladin** is `locHead 1.0` → **0.5× / 1.0×** (it one-shots via raw damage, not headshots). Adding Deadshot raises the bonus sum: e.g. trash with American Sniper ≈ `5.0 × (0.5 + 1.6) = ×10.5` on a locHead-5.0 gun.

---

## 8. Widow's Wine — 4,000 Points

**Base abilities:**
- **Widow's Wine grenades** (replace your lethal grenade) — sticky, Semtex-like; zombies caught in the blast but not killed are webbed: those closest (≤100u) are **frozen for 16 s**, farther ones (≤256u) **slowed for 12 s** (stock `WIDOWS_WINE_COCOON_DURATION` 16.0 / `_SLOW_DURATION` 12.0 — unchanged). **(BASE)**
- **Self-defense webbing** — when a zombie melees you, you release a burst of webbing that webs nearby zombies (**16 s** frozen / **12 s** slowed). **(BASE)**
- **Webbing melee** — meleeing a zombie coats it in webbing and slows it. **(BASE)**
- **Web grenades restock 2 at the start of each round** (also refill on Max Ammo and from blue spider-drop pickups). **(BASE)**

**Mega — Spiderman:**
- **6 usable web grenades** — a GSC **virtual pool** of 6 throws that auto-refills the lethal clip on use (the engine clamps the clip to ~2 in a usermap, so the old clip-fill never held — the docs/30 GDT carry-cap raise is **abandoned**). A custom **WEB GRENADES** HUD counter (top-left, under MEGA BOTTLES) shows the true count; the stock grenade-clip HUD stays clamped and isn't authoritative.
- **Restock 4 web grenades to the pool each round** (instead of base 2).
- **One-hit melee on regular zombies** (user 2026-06-18) — a melee from a Mega-Widow's player instakills a normal zombie; **not bosses/elites** (`is_boss_or_elite` gate). Re-adds the melee OHK the 2026-06-14 overhaul removed; the web-grenade OHK stays removed. GSC short-circuit in `_acc_damage::on_ai_damage`.

---

## 9. PhD Flopper — 2,500 Points *(custom — not a stock BO3 perk, so no `(BASE)` tags)*

> A custom ability that **hijacks** the stock electric-cherry pipeline + machine (the underlying
> specialty stays `specialty_electriccherry`); our `_acc_perk_phd_flopper.gsc` drives it. Adapted
> from the shipped HarryBo21/ColDog PhD Flopper.

**Base abilities:**
- **Explosive immunity** — immune to fall damage and to your own explosive / grenade / projectile-splash damage.
- **Slide-to-explode** — starting a slide sets off a nova that clears nearby zombies (on a cooldown). BO3 ZM has the sprint-slide but **no dolphin-dive** (confirmed in-game), so it triggers off the engine `isSliding()` directly — not the BO1/BO2 dive.
- **Explode when you go down** — entering last-stand sets off an explosion around you.
- **Blast look & feel** — the burst spawns on the **zombie you slide into** (the impact point, not on you): a **purple/void Apothicon burst** (stock `dlc4/genesis/fx_apothicon_fury_spawn_in_exp`), the **Nuke-powerup "whoomp"** sound (`evt_nuke_flash`), and a screen-shake. (A truly bespoke purple FX would need the FX Editor / a custom import; this reuses a stock purple effect that ships in the Mod Tools.)
- **Zombies explode** — every zombie the nova kills **pops apart**: head-gib (the Nuke powerup's own dismember death) + a torso gore burst + a corpse-fling away from the blast (capped at 6, Mega 8). Bosses (huge HP) are only chipped, never gibbed/flung.

**Mega — PhD Slider:**
- **Bigger, stronger slide + down explosion** — radius 300 → 500u and roughly **2× damage** on both the slide nova and the down explosion, on a **shorter slide cooldown** (8s → 5s). Live from the Mega flag.
- **1.35× SLIDE speed** (user 2026-06-18) — slide-GATED, not always-on: while you're sliding you move at 1.35× (a watcher sets `acc_mega_flopper_speed` only while `IsSliding`, mirroring the Rocket Shield; recomputed by `acc_utility::recompute_move_speed`, dvar `acc_mega_flopper_slide_mult`). Stacks **multiplicatively** with the Rocket Shield's own 1.35× slide bonus (see docs/12).
- **+15% explosive damage** (user 2026-06-18, nerfed from +20%) — your grenades / projectiles / `MOD_EXPLOSIVE` deal +15% to zombies. A GSC damage-dealt scalar in `_acc_damage::on_ai_damage` (gated on `has_active_mega_perk`) — **no weapon twin needed** (twins are only for weapon-GDT stats like recoil / a gun's base damage).
