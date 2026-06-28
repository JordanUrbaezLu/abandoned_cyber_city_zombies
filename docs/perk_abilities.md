# Perk Abilities — Full List

What every perk in `zm_abandoned_cyber_city` does — base tier and Mega tier, one bullet per effect. Companion to the design spec [13_perks.md](13_perks.md) (source of truth for numbers and stacking).

**`(BASE)`** = stock *Black Ops III* behavior inherited from the vanilla game. Untagged bullets are custom to this map (new or retuned). Mega tiers are all map-specific, so no Mega bullet is `(BASE)`. Deadshot, PhD Flopper, and Electric Cherry are custom perks, so they carry no `(BASE)` bullets.

## Map-wide perk rules

- **10 perks total** — 7 stock BO3 perks (retuned) + 3 custom (Deadshot, PhD Flopper, Electric Cherry). All 10 are live on the map today.
- **Start at 4 perk slots; buy more with Data Shards (up to 10).** The base cap is `level.perk_purchase_limit = 4`; each extra slot is bought at the underground **Neural Expansion Bay** for an escalating shard cost (4/6/8/10/12/14), raising the per-player limit via the stock hook `level.get_player_perk_purchase_limit` (`acc_perks::acc_perk_slot_limit`). This is the marquee trench incentive — see [13_perks.md](13_perks.md) Perk-Slot Rule.
- **Where to buy:** all perks are at the **Lab** (random per-round rotation machines for the 9 rotating perks; Electric Cherry has its own dedicated alcove). Perks cost **Points**.
- **Mega tiers are not bought with Points.** Each base perk has a **Mega** upgrade unlocked by spending **1 Empty Mega Bottle** (dropped on every boss kill) at a Lab machine while you own the base perk and it is in rotation. Mega is **sticky for the run** (survives death/re-buy).
- **Player HP baseline:** no perk = **100 HP**, down on the **3rd** regular zombie melee hit.
- Buying all 10 base perks = **30,500 Points** (Double Tap lowered 5,000 → 3,000, user 2026-06-25; Electric Cherry 3,000).

---

## 1. Jugger-Nog — 4,000 Points

**Base abilities:**
- Raises max health to **250 HP** (no-perk base is **100 HP**). **(BASE)**
- Survive **5** regular zombie melee hits — **down on the 6th** (no perk: down on the 3rd).

**Mega — Ultimate Tank:**
- Raises max health to **300 HP** — survive **6** hits, **down on the 7th**.

> *Boss-special immunity used to live here, then on Mega Widow's — it now belongs to **Mega Electric Cherry ("Power Surge")** (user 2026-06-25). Mega Jug is HP only.*

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
- **−50% incoming damage while you are reviving a teammate** (×0.50 for the whole revive channel) — so you're far harder to punish for stopping to pick someone up. Stacks multiplicatively with the Exo Suit resist; self-revive doesn't qualify.

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

## 4. Double Tap 2.0 — 3,000 Points

*The full stock **Double Tap II Root Beer** — kept as-is. The extra bullet can't be disabled from a usermap, so we embrace it and balance around it.*

> **Design decision (2026-06-14):** the base perk IS the stock `specialty_doubletap2` machine,
> which fires an **extra bullet per shot** (≈2× damage). There is no usermap-side way to strip
> that, so we KEEP Double Tap **2.0** (not "1.0") and price/balance around what we have. It
> costs **3,000** (lowered from 5,000 on 2026-06-25; doubling bullet output is a major damage
> perk, but 5,000 priced it out). The Mega adds fire rate + faster swap via the `fastfire` weapon-variant twin.

**Base abilities (Double Tap 2.0):**
- **Fires 2 bullets per shot for the cost of 1 round of ammo** (double the pellets on shotguns). **(BASE — stock 2.0)**
- **Each Double-Tap bullet is tempered to 0.6× damage** on this map (`ACC_DOUBLETAP_DMG_MULT`, dvar `acc_doubletap_dmg_mult`, `_acc_damage.gsc`). The stock extra bullet is engine-level and **can't be stripped** in a usermap, so instead of a flat ~2× we cut each bullet's damage → net **~1.6× DPS** (2 bullets × 0.6 × the +33% fire rate). Applies to **standard bullet guns only** (the `weapon_gets_dt_bullet` allow-list — never Wonder Weapons / Ballistic Knife / launchers / explosives / melee, which don't fire the extra bullet). Applies to **base AND Mega**.
- **+33% rate of fire** (the stock Double Tap rate boost). **(BASE)**

> *Double Tap is **not** a defensive perk — it gives **no** resistance to incoming damage. The only "reduction" it carries is the 0.6× temper on its **own** bullets, above. Player damage-resistance comes from Jugger-Nog (HP) and the Exo Suit (−5%/tier).*

**Mega — Gun Slinger:**
- **+45% rate of fire** (on top of the 2.0 base; `fastfire` twin, fireTime ×0.69 — raised from +40% on 2026-06-25; originally +50%).
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
- **+1.3 headshot damage bonus** (`ACC_DEADSHOT_MULT`; added into the headshot/crit bonus pool, not multiplied — 2026-06-14).
- **Snaps to the nearest head while aiming down sights** (not on bosses).
- *(No recoil change — recoil reduction moved to the Mega tier 2026-06-16.)*

**Mega — American Sniper:**
- **+1.5 headshot damage bonus** (`ACC_DEADSHOT_MEGA_MULT`; replaces the base +1.3 — no double dip; retuned 1.8→1.5).
- **−50% weapon recoil** → 1.75 × 0.50 = **0.875× vanilla** (below stock — a genuinely steady gun).

**Effective headshot damage** — the map's **headshot loc-temper** is applied *multiplicatively* to a head hit: `locHead × 0.5` on trash (`ACC_HEADSHOT_MULT`) / `locHead × 0.6` on bosses (`ACC_BOSS_HEADSHOT_MULT`). Most box guns are `locHead 5.0`, so a no-perk headshot ≈ **×2.5 body (trash) / ×3 body (boss)**; **Paladin** is `locHead 1.0` → **×0.5 / ×0.6** (it one-shots via raw damage, not headshots). Deadshot's bonus stacks *additively* into the separate crit-damage pool on top: **+1.3** base / **+1.5** with American Sniper (per `_acc_damage.gsc::on_ai_damage`).

---

## 8. Widow's Wine — 4,000 Points

**Base abilities:**
- **Widow's Wine grenades** (replace your lethal grenade) — sticky, Semtex-like; zombies caught in the blast but not killed are webbed: those closest (≤100u) are **frozen for 16 s**, farther ones (≤256u) **slowed for 12 s** (stock `WIDOWS_WINE_COCOON_DURATION` 16.0 / `_SLOW_DURATION` 12.0 — unchanged). **(BASE)**
- **Self-defense webbing** — when a zombie melees you, you release a burst of webbing that webs nearby zombies (**16 s** frozen / **12 s** slowed). **(BASE)**
- **Webbing melee** — meleeing a zombie coats it in webbing and slows it. **(BASE)**
- **Web grenades restock 2 at the start of each round** (also refill on Max Ammo and from blue spider-drop pickups — killing a *webbed* zombie drops one at **10%** web-grenade kill / **15%** gun / **20%** knife; see *Spider-drops* under Mega). **(BASE)**

**Mega — Spiderman:**
- **One-hit melee on regular zombies** (user 2026-06-18) — a melee from a Mega-Widow's player instakills a normal zombie; **not bosses/elites** (`is_boss_or_elite` gate). GSC short-circuit in `_acc_damage::on_ai_damage`. *(The old 6-web-grenade virtual pool + 4/round restock + WEB GRENADES HUD were removed 2026-06-24 — Mega Widow's uses stock web-grenade behavior now.)*
- **Spider-mobility while low** (user 2026-06-25) — you scuttle dramatically faster the lower you are: **crouch ×2.6, prone ×10, last-stand (downed) ×15** the normal speed of *that stance*. It **multiplies** the move scale, so versus another player in the *same* stance you move N× faster; standing is unchanged. A per-player stance watcher (`_acc_mega_bottles::mww_stance_speed_watch`, off `GetStance()` + `.laststand`) drives it through the single move-speed owner (`acc_utility::recompute_move_speed`, applied after the base cap; final clamp `acc_mww_speed_cap` raised to 16 to fit the ×15). Live dvars `acc_mww_crouch_speed` / `acc_mww_prone_speed` / `acc_mww_down_speed`. **Down-ownership fix (user 2026-06-25):** going into last stand makes the engine report the perk as LOST, which would kill the crawl speed exactly when you want it — so the watcher **snapshots** legit ownership every tick while *up* into `player.acc_mww_down_owner`, and the down branch gates the ×15 on that snapshot. So a downed holder keeps the crawl speed through the whole bleed-out. *(The ×15 down still depends on the engine applying the move scale to the laststand crawl — crouch/prone are solid; verify the down rate in-game.)*
- **More spider-drops** (user 2026-06-26) — Mega "Spiderman" adds **+10 percentage points** to the spider-drop chance on every kill type, so killing a *webbed* zombie drops the blue web-grenade refill pickup more often: web-grenade kill **10% → 20%**, gun kill **15% → 25%**, Widow's-knife kill **20% → 30%** (base rates are the **10 / 15 / 20%** in the Base list above). **We own the whole roll:** the stock chances are unchangeable `#define`s in `_zm_perk_widows_wine.gsc`, and the *base* needed to go **below** stock (stock is 15/20/25), so a spawn hook (`_acc_mega_bottles::mww_suppress_stock_spider_drop`, via `callback::on_ai_spawned`) sets `b_widows_wine_no_powerup` to disable the stock auto-drop per-zombie — that field is **read-only everywhere in stock** (only `_zm_perk_widows_wine.gsc:313` reads it), so once set at spawn it sticks — and the death hook (`mww_spider_drop_roll`) does the **single** replacement roll → exact rates, **no double-drops**. Live dvars `acc_widow_spider_web_pct` (10) / `acc_widow_spider_gun_pct` (15) / `acc_widow_spider_knife_pct` (20) / `acc_widow_mega_spider_add_pct` (10); set `acc_widow_spider_custom 0` to revert to stock entirely. Pairs naturally with the one-hit knife, which lands kills in the **20% → 30%** (highest) melee tier.

> *Boss-special immunity is **no longer** on Mega Widow's — it moved to **Mega Electric Cherry ("Power Surge")** (user 2026-06-25). The immunity gates in `_acc_boss::protect_immune_players_during_debuff` + `_acc_elites::acc_phantom_chain_zap` now check `specialty_combat_efficiency`, not `specialty_widowswine`.*

---

## 9. PhD Flopper — 2,500 Points *(custom — not a stock BO3 perk, so no `(BASE)` tags)*

> A custom ability that **hijacks** the stock electric-cherry pipeline + machine (the underlying
> specialty stays `specialty_electriccherry`); our `_acc_perk_phd_flopper.gsc` drives it. Adapted
> from the shipped HarryBo21/ColDog PhD Flopper.

**Base abilities:**
- **Explosive immunity** — immune to fall damage and to your own explosive / grenade / projectile-splash damage.
- **Explode when you go down** — entering last-stand sets off an explosion around you (this is base PhD's nova trigger).
- *(**Slide-to-explode is Mega-only** as of 2026-06-26 — base PhD no longer detonates when you start a slide; **only PhD Slider does**, see below. BO3 ZM has the sprint-slide but **no dolphin-dive** (confirmed in-game), so the Mega triggers off the engine `isSliding()` directly — not the BO1/BO2 dive.)*
- **Blast look & feel** — the burst spawns on the **nearest zombie in range** (the impact point, not on you — i.e. the zombie you slid into, on the Mega slide): a **stock orange explosion** (`level._effect["def_explosion"]`) + a screen-shake (user 2026-06-25, swapped off an electric spark-burst — *"why does PhD slide spark"*). **Sound differs by tier** (user 2026-06-22): **base = `def_explosion`'s own bomb boom** (no extra cue); **Mega = the Nuke-powerup "whoomp"** (`evt_nuke_flash`) layered over it.
- **Zombies explode** — every zombie the nova kills **pops apart**: head-gib (the Nuke powerup's own dismember death) + a torso gore burst. Bosses (huge HP) are only chipped, never gibbed. *(The old **corpse-fling** ragdoll was **removed 2026-06-24** — it caused the "invisible zombie keeps hitting me after a PhD slide" bug: `StartRagdoll` fired in the same frame as the killing damage, racing the engine's death handling so the model flung out of view while the AI kept swinging. It was also invisible on this map anyway — bodies are deleted within ~0.05s of death — so removing it costs nothing visible.)*

**Mega — PhD Slider:**
- **Slide-to-explode (Mega-exclusive)** — **only PhD Slider detonates on a slide** (base PhD doesn't; user 2026-06-26). The base on-down nova is **300u**; the Mega slide/down nova is **250u** (user 2026-06-27, HALVED from 500) and **capped at 10 zombies hit per slide** (`acc_phd_max_hits`) so it can't clear a whole pile. Mega slide cooldown **8s** vs base **10s** (user 2026-06-22, was 5s/8s). The Mega nova **damage** is **FROZEN at a round-16 normal-zombie's health** (user 2026-06-27; dvar `acc_phd_freeze_round` 16, scaled by the co-op regular-HP mult): **one slide one-shots trash through round 16**, then takes **2 slides** (~r17–23), then **3** (~r24–27), as zombies outscale the frozen value. It's dealt **raw** — the nova bypasses the global ×2.75 buff + the whole bonus chain (the `acc_phd_nova_hit` tag in `_acc_damage::on_ai_damage`), so the frozen number is exactly what lands; it can't balloon past r18 or nuke bosses (the 10% boss per-hit cap still applies). *(Was ~0.8× the LIVE round health × the global ×2.75 + Mega Flopper +15% — which one-shot at EVERY round, "a single slide" forever, and read ~64k vs bosses.)*
- **1.5× SLIDE speed** (user 2026-06-22, was 1.35×) — slide-GATED, not always-on: while you're sliding you move at 1.5× (a watcher sets `acc_mega_flopper_speed` only while `IsSliding`, mirroring the Rocket Shield; recomputed by `acc_utility::recompute_move_speed`, dvar `acc_mega_flopper_slide_mult`). Stacks **multiplicatively** with the Rocket Shield's own 1.35× slide bonus (→ ~2.0× with both, see docs/12).
- **+15% explosive damage** (user 2026-06-18, nerfed from +20%) — your grenades / projectiles / `MOD_EXPLOSIVE` deal +15% to zombies. A GSC damage-dealt scalar in `_acc_damage::on_ai_damage` (gated on `has_active_mega_perk`) — **no weapon twin needed** (twins are only for weapon-GDT stats like recoil / a gun's base damage).

---

## 10. Electric Cherry — 3,000 Points *(custom — the REAL 10th perk, not a stock BO3 perk, so no `(BASE)` tags)*

> A genuinely new perk built from scratch on the unused engine specialty `specialty_combat_efficiency`
> (Elemental Pop precedent), with its **own** Lab alcove + the real `p6_zm_vending_electric_cherry` machine.
> It does **not** touch PhD Flopper, which keeps hijacking `specialty_electriccherry` — so both coexist.
> Code: `_acc_perk_electric_cherry.gsc`.

**Base abilities:**
- **Reload discharges an electric nova** — reloading electrocutes nearby zombies (adapted from stock `_zm_perk_electric_cherry`).
- **The emptier your mag, the bigger the blast** — reloading a near-empty mag = a big nova (one-shots trash at any round); reloading a full mag = just a spark. (We fixed the stock 1/10 clip-fraction stub to read the real `GetWeaponAmmoClip / clipSize`.)
- **Survivors are stunned** — zombies the nova doesn't kill are frozen with the stock tesla stun + shock FX (~4 s); lethal hits get the full electrocution.
- **Cooldown** between nova discharges stops reload-spam. *(No last-stand explosion — PhD Flopper owns the single global down-explosion hook.)*

**Mega — Power Surge:**
- **Stronger, faster nova** — more targets (12), higher damage (+50%), shorter cooldown (5 s), read live from the Mega flag. *(Radius is NOT increased at the signature empty-mag reload — the Mega's edge is damage/targets/cooldown by design; `EC_RADIUS_MAX_MEGA` 200 vs base `EC_RADIUS_MAX` 220.)*
- **Immunity to boss specials** — a Power-Surge holder ignores the **Phantom chain-zap slow** and the **Subroutine Core power/perk-disable** (moved here from Mega Widow's, user 2026-06-25). Enforced in `_acc_boss::protect_immune_players_during_debuff` + `_acc_elites::acc_phantom_chain_zap`, which gate on the **persistent** Mega flag `specialty_combat_efficiency` — the only ownership marker that survives the boss's `UnsetPerk` debuff, which is exactly why the immunity must live on the Mega tier, not base.
