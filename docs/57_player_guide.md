# Abandoned Cyber City — New Player Guide

*A quick, complete guide for anyone jumping into the map for the first time. Read it in
five minutes, then go play. Numbers here track the actual code — if something feels off,
the code wins. (Verified against the code 2026-06-26.)*

---

## The 60-second version

- You have **two currencies.** **Points** (cash) keep you alive *this* round — guns, doors,
  perks, Pack-a-Punch. **Data Shards** are the rare upgrade currency, earned and spent
  **underground in the trench**, and they make you permanently stronger.
- **Guns** come from the wall and the **Mystery Box**. The better a gun packs, the **more it
  costs to Pack-a-Punch** — and *usually* the **rarer it rolls** (a couple of guns break that
  rule on purpose).
- **Pack-a-Punch has 3 levels** (I → II → III). Each level costs more for stronger guns, and
  the damage climbs **+33% / +67% / +100%** over the base gun.
- The **trench** (underground) is the high-risk, high-reward heart of the map: amped
  zombies that get worse the deeper you go, but it's the only place to earn **Data Shards**.
- Spend Shards on **perk slots**, the **Exo Suit** (your body), the **Weapon Overclock**
  (your gun), and the **Glitch Altar** gamble.

**Core loop:** survive up top for cash → drop into the trench for Shards → spend Shards on
permanent power → come back able to go deeper → repeat.

---

## Guns: tiers, Pack-a-Punch cost, and box odds

Every gun is rated **Base** (off the wall / box) and **Packed** (fully Pack-a-Punched).
The stronger a gun is when packed, the **more each Pack-a-Punch level costs** — and *usually*
the **rarer it rolls in the box** (a couple of guns are deliberately tuned to roll commonly
even though they pack into something strong).

**Tiers:** **S** = best, then **A**, **B**, **C** (a `+`/`-` is just a notch within a tier).
**PaP cost** is the three upgrade steps **I / II / III** (you pay each in turn).
**Box roll** is roughly how often that gun comes up when you spin the Mystery Box.

| Gun | Class | Base | Packed | PaP cost (I / II / III) | Box roll |
|---|---|:--:|:--:|---|--:|
| **Chicom CQB** (3-round burst) | SMG | S+ | **S** | 5000 / 7500 / 10000 | ~2.4% |
| **M60** | LMG | S | **S** | 5000 / 7500 / 10000 | ~2.0% |
| **AK-74u** | SMG | A | **S** | 5000 / 7500 / 10000 | ~5.9% |
| **PPSh-41** | SMG | S | **S** | 5000 / 7500 / 10000 | ~2.0% |
| **Tac-19** (energy shotgun) | Shotgun | A | **A** | 5000 / 7500 / 10000 | ~2.0% |
| **MORS** (railgun sniper) | Sniper | S | **A** | 5000 / 7500 / 10000 | ~2.4% |
| **AE4** | AR | B | **A** | 4000 / 6000 / 8000 | ~5.9% |
| **RW1** (energy pistol) | Pistol | A | **A** | 4000 / 6000 / 8000 | ~5.9% |
| **AK-47** | AR | A | **A** | 4000 / 6000 / 8000 | ~5.9% |
| **ASM1** | SMG | B | **A** | 4000 / 6000 / 8000 | ~5.9% |
| **Galil** | AR | B+ | **A** | 4000 / 6000 / 8000 | ~5.9% |
| **Paladin HB50** | Sniper | B | **B** | 3000 / 4500 / 6000 | ~10.1% |
| **RPD** | LMG | C | **B** | 3000 / 4500 / 6000 | ~10.1% |
| **Five-Seven** (start pistol) | Pistol | C- | **B** | 3000 / 4500 / 6000 | ~10.1% |
| **MK14** | DMR | B | **B** | 3000 / 4500 / 6000 | ~5.9% |
| **Olympia** | Shotgun | C | **C** | 3000 / 4500 / 6000 | ~10.1% |

> **Two guns break the "good = rare" rule on purpose:** **AK-74u** packs all the way to S
> but still rolls common (~5.9%), and **MK14** is a cheap BOT-priced gun that also rolls
> common — so don't be surprised when they show up a lot.

### Special weapons (box only)

| Weapon | What it is | PaP cost (I / II / III) | Box roll |
|---|---|---|--:|
| **Thundergun** | Wonder weapon — wind blast clears a room. One per game, the rarest pull of all. | 5000 / 7500 / 10000 | ~0.6% |
| **Action Figure** | Melee special — Pack-a-Punches **in place** (no swap); each level adds a chance to **cleave extra zombies** per swing. | 5000 / 7500 / 10000 | ~1.0% |
| **Mahem** | Explosive rocket launcher. | 4000 / 6000 / 8000 | ~5.9% |

> **Reading the odds:** percentages are the gun's share of the box pool (19 weapons). The box
> **never hands you a gun you're already holding**, so as you collect, the remaining guns come
> up more often. Before each gun roll the box also does a rare **equipment pre-roll** —
> **Monkey Bomb ~1%**, **Li'l Arnie ~0.5%** — which nudges every gun's *real* chance down by
> about 1.5%. **The best guns are deliberately rare** — that S-tier roll is supposed to feel
> like a win.

---

## Data Shards — the upgrade currency

Data Shards are the map's second currency — separate from points. You spend them on the deep
upgrade sinks: the **Exo Suit**, per-gun **Overclocks**, perk slots at the **Neural Expansion
Bay**, and gambling at the **Glitch Altar**. Points buy guns and perks; shards buy *power*.
Your shard count rides at the top-left of the HUD (it glows dim until you bank your first one).

**Cap: 500.** That's the most you can hold in normal play — high enough to bank toward the
multi-tier sinks, finite so you can't hoard forever.

### Where shards come from

| Source | Where | Reward |
|---|---|---|
| **Data Caches** (×2) | The exposed pit floor (one west, one east) | **+3 each**, once per round, first-come. They re-arm every round (a dim white glow = "shards here this round"). In co-op, once you grab a cache you **can't take the other one** that round — leave it for a teammate. Solo, take both. |
| **Trench Warden** (a Brutus) | Spawns in the pit on the boss rounds | **+3 to every player**, guaranteed. (He also drops a boss item.) |
| **Phantom** (boss) | Boss event | **+5 to every player**, guaranteed — same idea as the Warden, bigger payout. |
| **Reactor Surge** | The arm plinth in the pit (free to arm) | Survive the **5-wave** surge → **everyone gets +5 plus a shared Insta-Kill.** Re-arms on a **3-round cooldown.** You must stay down in the trench to collect — bail out and you get nothing. |
| **Glitch Altar** | Deep underground | A **2-Shard gamble**, not a faucet — see below. |

### The Glitch Altar (gamble — net-negative on shards)

Each spin costs **2 Data Shards** and rolls a weighted result: **~65% boon / ~35% curse**
(curses never down you). Boons are Max Ammo, Insta-Kill, Double Points, a free perk, a
**Shard Jackpot (+4)**, or the rare **Mega Win** (free perk *and* Insta-Kill). Curses are a
zombie **surge**, a small **Shard Drain (−2)**, or a **dud**. Even the jackpot only partly
refunds the spin, so the altar **drains** shards over time — spin it for the perks and
power-ups, not to grow your bank.

---

## The Trench — how it works

The Bus Station has a wide trench cut dead-centre. The two doors that open the Bus Station
cost **1000 each** and need **no power** (this room is where you go to turn the power on). The
whole sub-level below the lip — the open pit, the side rooms, and every Abyss floor — counts
as "the trench," so its danger applies the moment your feet drop below the rim.

**Getting down.** There's a thin stair walkway you can take for free, but the fast way is to
just **jump in**. A jump/fall in costs a flat **25 fall tax** (it only fires on a real drop —
walking the stairs pays nothing). It reads as a fall, so **PhD Flopper negates it for free**.
The drop can't kill you (native fall damage is off map-wide); the zombies are the only danger.

**It goes DEEP.** Below the pit the Abyss descends in **5 layers total**, each **240u** lower
than the last (L1 = the pit, down to L5 at the bottom). Every layer you go deeper, the zombies
scale up:

| Per layer DEEPER | Effect |
|---|---|
| Move speed | **+5%** |
| Health | **+50%** (one-way — they keep it as they descend) |
| Melee damage | **+10 HP** (a flat add, not a percent) |

So a zombie on Layer 3 is roughly +15% speed, +150% health, and hits for +30 over a surface
zombie — and entering or descending a layer also bursts a **surge** of extra zombies right
where you're standing. Going deeper is pure risk-for-reward.

**The slow.** Being below your gear's coverage slows you down: you move full speed through any
layer your **Exo Suit** tier covers, then **−20%** on the first uncovered layer and **−10% per
layer** deeper. Only the Exo Suit cancels this (see below) — it's the key to the deep floors.

> **Don't camp the bridge.** The elevated, double-jump-only bridge at the top of the trench is
> zombie-unreachable, so parking on it bleeds **15% of your max health per second** after a
> couple seconds. Cross it, don't camp it.

### Perk slots — the Neural Expansion Bay

You **start with 4 perk slots.** The **Neural Expansion Bay** vendor (down in the trench)
sells extra slots for **Data Shards**, up to **10**. Each slot costs more than the last:

| Buying slot # | 5th | 6th | 7th | 8th | 9th | 10th |
|---|:--:|:--:|:--:|:--:|:--:|:--:|
| **Data Shards** | 4 | 6 | 8 | 10 | 12 | 14 |

That's **54 Shards** to go from 4 slots all the way to 10. Per-player — everyone buys their own.

---

## The Exo Suit — your body upgrade

If the Weapon Overclock is your gun's brain, the **Exo Suit** is your body. It's a
**per-player** upgrade bought with **Data Shards** at the workbench station down in the trench
(in the Foundry). The trench's deep layers hold the best Shards but **slow you down** the
deeper you go — and the Exo Suit is the *only* thing that cancels that slow, so it's the key
that unlocks the depths. It also toughens you and turns your knife into a real weapon.

**10 tiers.** Your HUD shows **EXO SUIT N/10**. Three augments scale together:

| Augment | Per tier | At Tier 5 | At Tier 10 |
|---|---|---|---|
| **Walk deeper at full speed** | +1 layer | full speed through layers 1–5 | (all 5 built layers) |
| **Damage resistance** | −5% | −25% | **−50%** |
| **Melee power** | +30% | +150% | **+300%** |

**The depth slow it cancels** — at any layer *deeper* than your Exo tier you move slower
(−20% at the first uncovered layer, then −10% per layer below, never past −90%):

| Your tier ↓ / Layer → | L1 | L2 | L3 | L4 | L5 |
|---|:--:|:--:|:--:|:--:|:--:|
| **0** | −20% | −30% | −40% | −50% | −60% |
| **2** | 0 | 0 | −20% | −30% | −40% |
| **4** | 0 | 0 | 0 | 0 | −20% |
| **5+** | 0 | 0 | 0 | 0 | 0 |

> The Abyss has **5 built layers** today, so the "walk deeper" gate maxes out at **Tier 5**.
> Tiers 6–10 still keep adding resistance (to −50%) and melee (to +300%) — they just don't
> unlock any *new* layer until deeper geometry exists. The slow re-applies on every spawn, so
> a death or revive won't strand you crawling.

**Cost:** **4 / 8 / 12 / 16 / 20 / 24 / 28 / 32 / 36 / 40** Shards per tier (= 4 × tier; **220**
to fully max). Hitting **Tier 5** — full Abyss travel, −25% resist, +150% melee — costs just **60**.

---

## The Weapon Overclock — your gun upgrade

Pack-a-Punch is a one-time power jump; the Overclock is **permanent, per-gun scaling** that
keeps a favorite weapon relevant deep into a run. Bought at the **Foundry terminal in the
trench** (it only works underground — any overclock kiosk above ground is dead). It's
**per-gun and per-player**, and the tier sticks to the weapon through Pack-a-Punch and perk
swaps. **Almost every weapon can be overclocked — including the Mahem and Thundergun. The only
one that can't is the Action Figure** (the Exo Suit scales your melee instead).

**10 tiers**, shown on the HUD as **vN**. Each tier nudges all four effects up at once:

| Effect | Per tier | At max (T10) | When it applies |
|---|---|---|---|
| **Flat damage** | +10% | **+100%** | always on, every gun hit |
| **Glitch piercing** | +25% | **+250%** | bonus damage vs glitch zombies only |
| **Ammo refund** | +10% chance | **100% chance** | on a **headshot kill** — refunds a mag (inert on Thundergun/Mahem, which don't headshot) |
| **Shield piercing** | partial restore | partial restore | punches through a Riot elite's frontal armor (below) |

> **Shield piercing, in detail:** a Riot elite's front only lets **25%** of your damage through
> at base. Overclock tiers chip that block down — to **~44% at T5** and **~62% at T10**. It's
> *always* a partial restore; even a maxed gun never fully bypasses the front armor, so
> flanking, explosives, and side-melee stay the real counters.

> The Overclock changes **damage and on-hit behavior** — it does *not* touch fire rate,
> reload, or mobility (those are baked into the weapon).

**Cost:** **4 / 8 / 12 / 16 / 20 / 24 / 28 / 32 / 36 / 40** Shards per tier (= 4 × tier; **220**
to fully max one gun — the same ladder as the Exo Suit). With the 500 cap you can max two guns
and still have change.

---

## Quick-start checklist

1. Grab a wall gun and open toward the **Bus Station** (corp zone).
2. Buy into the trench (1000 a door) and **drop into the pit**.
3. **Loot the two Data Caches** every round (+3 each); kill the **Trench Warden** when he shows.
4. Spend your first Shards on **perk slots** (Neural Expansion Bay) and an early **Exo Suit**
   tier so the trench stops slowing you.
5. Find a gun you like, **Pack-a-Punch** it, then **Overclock** it as Shards come in.
6. Arm the **Reactor** for a big Shard + Insta-Kill payout, push a layer deeper, repeat.

*Good luck out there.*
