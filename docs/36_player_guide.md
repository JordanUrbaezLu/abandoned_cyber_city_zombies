# Abandoned Cyber City — New Player Guide

*A quick, complete guide for anyone jumping into the map for the first time. Read it in
five minutes, then go play. Numbers here track the actual code — if something feels off,
the code wins. (Verified against the code 2026-07-10.)*

---

## The 60-second version

- You have **two currencies.** **Points** (cash) keep you alive *this* round — guns, doors,
  perks, Pack-a-Punch. **Data Shards** are the rare upgrade currency, earned and spent
  **underground in the trench**, and they make you permanently stronger.
- **Guns are box-only.** There's one starting pistol (Five-Seven); everything else comes out
  of the **Mystery Box**, which pulls from a large arsenal. The stronger a gun is when packed,
  the **more it costs to Pack-a-Punch** — and the **rarer it rolls** (the best guns are
  deliberately hard to draw). Two S-tier guns are wall-buys deep in the Abyss (below).
- **Pack-a-Punch has 3 levels** (I → II → III). Each level costs more for stronger guns, and
  the damage climbs **+33% / +67% / +100%** over the base gun.
- The **trench** (underground) is the high-risk, high-reward heart of the map: amped
  zombies that get worse the deeper you go, but it's the only place to earn **Data Shards**.
- Spend Shards on **perk slots**, the **Exo Suit** (your body), the **Weapon Overclock**
  (your gun), and the **Glitch Altar** gamble.

**Core loop:** survive up top for cash → drop into the trench for Shards → spend Shards on
permanent power → open the soul-box gates and go deeper → repeat, all the way down to Paradise.

---

## Guns: tiers, Pack-a-Punch cost, and box odds

Every gun is ranked on its **packed** power. That single rank drives two things at once: the
**more each Pack-a-Punch level costs**, and the **rarer the gun rolls in the box** — so the best
packed guns are the priciest to upgrade *and* the hardest to find.

**Pack-a-Punch price tiers** (the three upgrade steps I / II / III, paid in turn):

| Price tier | I | II | III | Who's in it |
|---|--:|--:|--:|---|
| **Wonder** | 10,000 | 15,000 | 20,000 | Thundergun, Blast-O-Matic, Fire Bow, Leviathan Axe |
| **Top** | 5,000 | 7,500 | 10,000 | XM4, AK-47, M60, PPSh-41, Peacekeeper, MORS, CEL-3, Action Figure, Havoc, Mahem, War Machine |
| **Mid** | 4,000 | 6,000 | 8,000 | AE4, RW1, MK14, Tac-19, AK-74u, RPD |
| **Bottom** | 3,000 | 4,500 | 6,000 | Alternator, Prowler, Streetsweeper, Olympia, Grav, G7 Scout, Five-Seven |

**Box roll** is roughly how often each gun comes up when you spin the Mystery Box, ranked from
rarest (best packed) to commonest (weakest packed). The percentages are each gun's share of the
box pool and are **auto-generated from the power ranking** (`acc_box_weight`), so they drift a
little whenever the arsenal is re-tuned — treat them as the *shape* of the odds, not gospel:

| # | Gun | Class | Box roll |
|--:|---|---|--:|
| 1 | **Thundergun** (wonder weapon) | Special | ~0.3% |
| 2 | **Blast-O-Matic** (energy blaster) | Special | ~0.3% |
| 3 | **Fire Bow** | Special | ~0.3% |
| 4 | **Leviathan Axe** | Melee special | ~0.3% |
| 5 | **Action Figure** (PaP in place) | Melee special | ~0.8% |
| 6 | **XM4** | AR | ~1.2% |
| 7 | **Havoc** (energy rifle) | Special | ~1.2% |
| 8 | **Peacekeeper** (lever shotgun) | Shotgun | ~1.3% |
| 9 | **AK-47** | AR | ~1.4% |
| 10 | **M60** | LMG | ~1.6% |
| 11 | **PPSh-41** | SMG | ~1.8% |
| 12 | **Mahem** (rocket launcher) | Special | ~2.0% |
| 13 | **War Machine** (drum GL) | Special | ~2.2% |
| 14 | **MORS** (railgun sniper) | Sniper | ~2.4% |
| 15 | **Alternator** | SMG | ~2.7% |
| 16 | **AE4** (energy AR) | AR | ~3.0% |
| 17 | **RW1** (energy pistol) | Pistol | ~3.3% |
| 18 | **CEL-3** (spread shotgun) | Shotgun | ~3.7% |
| 19 | **MK14** | DMR | ~4.1% |
| 20 | **Tac-19** (energy shotgun) | Shotgun | ~4.6% |
| 21 | **Prowler** (burst SMG) | SMG | ~5.1% |
| 22 | **AK-74u** | SMG | ~5.6% |
| 23 | **Streetsweeper** (drum shotgun) | Shotgun | ~6.2% |
| 24 | **RPD** | LMG | ~6.9% |
| 25 | **Olympia** | Shotgun | ~7.7% |
| 26 | **Grav** | AR | ~8.5% |
| 27 | **G7 Scout** (marksman) | Sniper | ~9.5% |
| 28 | **Five-Seven** (start pistol) | Pistol | ~10.5% |

> **The four wonder weapons (Thundergun, Blast-O-Matic, Fire Bow, Leviathan Axe) are the rarest
> pulls of all (~0.3% each) and are claim-capped to one in the world.** The **Action Figure**
> Pack-a-Punches **in place** (no swap) instead of transforming. You don't need to memorize the
> table — the takeaways are: **specials and wonders are rare and expensive, the cheap common guns
> pack into solid-but-modest weapons, and every packed form still scales further with the Weapon
> Overclock (below).**

> **Reading the odds:** before each *gun* roll the box does a rare **equipment pre-roll** —
> **Monkey Bomb ~1%**, **Li'l Arnie ~0.5%** — which nudges every gun's *real* chance down by
> about 1.5%. The box also **never hands you a gun you're already holding**, so as you collect,
> the remaining guns come up more often.

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
| **Any boss kill** | Boss rounds (see below) | **Every boss pays the same guaranteed reward** to every player: **round × 180 points + ⌊round ÷ 3⌋ shards**, plus a **boss item** and a **Mega Bottle**. (Round 9 = ~1,620 points + 3 shards; round 18 = ~3,240 + 6.) This covers the **Trench Warden** (Brutus), **Phantom**, **Avogadro**, **Panzer**, and the **Rogue Protector** alike — they were unified 2026-07-05, no more per-boss differences. *(Bosses spawned during the Paradise finale pay nothing — that fight is survive-don't-farm.)* |
| **Reactor Surge** | The arm plinth down in the trench (free to arm) | Survive the **5-wave** surge → **everyone gets +5 shards, a shared Fire Sale, and a Mega Bottle.** Re-arms on a **3-round cooldown.** You must stay down in the trench to collect — bail out and you get nothing. |
| **Glitch Altar** | Deep underground (Abyss Layer 3) | A **2-Shard gamble**, not a faucet — see below. |
| **Glitch Stalker** | A mobile mini-boss that blinks in on some rounds | **+1 shard to whoever kills it** (plus its own item + bottle). |

**Boss rounds:** the first **mini-boss** (the Trench Warden / Brutus) shows up around **round 5**
when the power comes on, then respawns on a timer. Full **boss rounds** land **every 9 rounds
from round 9** (9, 18, 27, …), and the *number* of bosses scales with the round (9 = 1, 18 = 2,
27 = 3, …). The boss **types** are dealt from a **shuffled 4-type deck** — **Phantom, Rogue
Protector, Avogadro, Panzer** — without repeats until the deck empties, so you won't see the same
boss twice in a round until very deep. Avogadro is the disruptor (stuns + hacks your perks/PaP);
kill him fast to get your utilities back.

### The Glitch Altar (gamble — net-negative on shards)

Each spin costs **2 Data Shards** and rolls a weighted result: **~65% boon / ~35% curse**
(curses never down you). Boons are Max Ammo, Insta-Kill, Double Points, a free perk, a
**Shard Jackpot (+4)**, or the rare **Mega Win** (free perk *and* Insta-Kill). Curses are a
zombie **surge**, a small **Shard Drain (−2)**, or a **dud**. Even the jackpot only partly
refunds the spin, so the altar **drains** shards over time — spin it for the perks and
power-ups, not to grow your bank.

---

## The Trench — how it works

The Bus Station has a wide trench cut dead-centre. The whole sub-level below the lip — the open
pit, the side rooms, and every Abyss floor — counts as "the trench," so its danger applies the
moment your feet drop below the rim.

**Getting down.** There's a thin stair walkway you can take for free, but the fast way is to
just **jump in**. A jump/fall in costs a flat **35 fall tax** (it only fires on a real drop —
walking the stairs pays nothing). It reads as a fall, so **PhD Flopper negates it for free**.
The drop can't kill you (native fall damage is off map-wide); the zombies are the only danger.

**It goes DEEP.** Below the pit the Abyss descends in **5 layers total**, each **240u** lower
than the last (Layer 1 = the pit, down to Layer 5 at the bottom). Every layer you go deeper, the
zombies scale up:

| Per layer DEEPER | Effect |
|---|---|
| Move speed | **+4%** |
| Health | **+30%** (one-way — they keep it as they descend) |
| Melee damage | **+6 HP** (a flat add, not a percent) |

So a zombie on Layer 3 is roughly +12% speed, +90% health, and hits for +18 over a surface
zombie. Going deeper is pure risk-for-reward.

**Opening the descent — the Soul Boxes.** You can't just walk to the bottom. Each layer is
sealed by a **Soul Box gate** at the stairwell down. A gate doesn't take currency — it opens when
the team **banks souls by slaying the horde on that layer** (one soul per kill on that floor). The
cost **scales with the live player count**:

- **First gate** (out of the trench / Layer 1, where everyone fights early): **125 souls per
  player** (125 solo → 500 at a full 4-player lobby).
- **Every deeper gate** (Layers 2, 3, 4): **50 souls per player** (50 solo → 200 at 4p).

A running **"Souls X / N"** message ticks up as you grind, and the gate pops with a chime when
it's paid. Four gates in all — one per step down to Layer 5.

> **Two S-tier wall-buys down the Abyss.** An **S-tier AK-47** is chalked on the south wall of
> **Layer 4**, and an **S-tier M60** on the south wall of **Layer 5 (the bottom)** — both **1500**.
> They're among the strongest guns in the game off the wall, but you have to fight four/five floors
> down to reach them. A real reason to commit to the descent, not just box-roll up top. (The M60
> sits right by the bottom Ammo Crate, before the Paradise door — gear up before the finale.)

**The slow.** Being below your gear's coverage slows you down: you move full speed through any
layer your **Exo Suit** tier covers, then **−20%** on the first uncovered layer and **−10% per
layer** deeper (never past −90%). Only the Exo Suit cancels this (see below) — it's the key to the
deep floors.

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
| **Damage resistance** | −6% | −30% | **−60%** |
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
> Tiers 6–10 still keep adding resistance (to −60%) and melee (to +300%) — they just don't
> unlock any *new* layer until deeper geometry exists. The slow re-applies on every spawn, so
> a death or revive won't strand you crawling.

**Cost:** **4 / 8 / 12 / 16 / 20 / 24 / 28 / 32 / 36 / 40** Shards per tier (= 4 × tier; **220**
to fully max). Hitting **Tier 5** — full Abyss travel, −30% resist, +150% melee — costs just **60**.

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
| **Flat damage** | +12% | **+120%** | always on, every gun hit |
| **Glitch piercing** | +15% | **+150%** | bonus damage vs glitch zombies only |
| **Ammo refund** | +5% chance | **50% chance** | on a **headshot kill** — refunds a mag (inert on Thundergun/Mahem, which don't headshot) |
| **Shield piercing** | partial restore | partial restore | punches through a Riot elite's frontal armor (below) |

> **Shield piercing, in detail:** a Riot elite's front only lets **25%** of your damage through
> at base. Overclock tiers chip that block down — to **40% at T5** and **55% at T10**. It's
> *always* a partial restore; even a maxed gun never fully bypasses the front armor, so
> flanking, explosives, and side-melee stay the real counters.

> The Overclock changes **damage and on-hit behavior** — it does *not* touch fire rate,
> reload, or mobility (those are baked into the weapon).

**Cost:** **4 / 8 / 12 / 16 / 20 / 24 / 28 / 32 / 36 / 40** Shards per tier (= 4 × tier; **220**
to fully max one gun — the same ladder as the Exo Suit). With the 500 cap you can max two guns
and still have change.

---

## The finale — Paradise

Layer 5 dead-ends at the **Paradise door**, a communal gate into the open-air plaza hub. Unlike
the soul-box gates, this one takes **currency from everyone** — and its price **scales with the
live player count**: **50 Data Shards + 50,000 points** solo, **+25 shards + 25,000 points per
extra player** (2p = 75/75k, 3p = 100/100k, 4p = 125/125k). You pay it in **installments** (up to
10 shards + 10k points per hold) into two shared pools, so nobody gets zeroed in one press. Once
**both** pools hit 0, **all living players must gather at the gate**, and then it opens for
everyone — kicking off the timed Paradise onslaught (survive the final fight to win).

---

## Quick-start checklist

1. Grab a wall gun and open toward the **Bus Station** (corp zone) to reach the power and the trench.
2. **Drop into the pit** and start banking Data Caches (+3 each) and souls.
3. Spend your first Shards on **perk slots** (Neural Expansion Bay) and an early **Exo Suit**
   tier so the trench stops slowing you.
4. Find a gun you like, **Pack-a-Punch** it, then **Overclock** it as Shards come in.
5. Arm the **Reactor** for a big Shard + Fire Sale payout; **bank souls to open the descent** and
   push a layer deeper. Grab the S-tier AK-47 (Layer 4) and M60 (Layer 5) wall-buys on the way.
6. At the bottom, pay the **Paradise gate**, gather the team, and survive the finale.

*Good luck out there.*
