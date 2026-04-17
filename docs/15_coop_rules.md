# 15 - Co-op Rules

Consolidated rules for 1-4 player multiplayer. If it says "co-op" or "multiplayer" elsewhere in the docs, this is the authoritative behavior.

## Player Count

- **Supported**: 1 - 4 players.
- **Solo**: fully supported; all systems work. No modifier or handicap required.
- **2p / 3p / 4p**: all supported identically. No "duos only" or "squad only" behaviors.
- **5+ players**: unsupported. Stock BO3 caps zombies at 4.

## Networking Model

- **Host-authoritative**. The map host is the server; clients predict and correct.
- **Split-screen**: supported via stock BO3 split-screen (2-player local co-op). Untested thoroughly with our custom systems; flagged for Phase 6 playtest.
- **Listen server**: assumed. Dedicated server is not a BO3 zombies thing.
- **Player proximity / host tethering**: stock BO3 has a ~1500 unit tether distance. We don't change this.

## Per-Player vs. Shared Resources

### Per-player (individual)

Every player has their own copy of these:

- **Points** - personal currency.
- **Data Shards** - personal.
- **Weapons** (weapon tiers, PaP levels, Overclocks slotted).
- **Cyberware tree** - independent per player; player A's Overclock Tier 2 doesn't affect player B.
- **Perks** - each player buys their own.
- **Boss items** - per-player inventory (2 slots each).
- **Weapon abilities** - each player has their own cooldowns.
- **HP / armor** - standard per-player.
- **Ability cooldowns** - independent.

### Shared (team-wide)

- **Round state** - all players progress through rounds together.
- **Power state** - power switch flip affects everyone.
- **PaP, Overclock Terminal, Mystery Box machines** - shared; no lockout per player.
- **Side event states** (Hack Terminal, Vault Overload) - one player activates; success/failure state is map-wide (one player can't activate Hack again if another failed it).
- **Map shortcuts unlocked by events** - map-wide.
- **Boss encounter state** - team-wide.

### Awarded per-player (independent of team)

- **Elite Data Shard drops** - go to the killer (pickup entity).
- **Boss Data Shard drops** - **every player gets the full amount independently** (not split). 4p co-op = 16 Shards per full boss.
- **Boss items** - per-player duplicate detection; one player's copy doesn't block another's pickup.
- **Side event rewards** - 2 Shards (Hack) or 3 Shards (Vault Overload) go to the activating player (plus any contributors via the 70/30 split for kills made during the event).

## HP Scaling

Stock BO3 scales HP per player count. Our rules:

| Target | Base HP | 2p mult | 3p mult | 4p mult |
|---|---|---|---|---|
| Regular zombie | 150 (round 1) | 2.00x | 3.00x | 4.00x |
| Elite (Shielded / Teleporter / EMP) | varies | 1.50x | 2.00x | 2.50x |
| Mini-boss (Juggernaut Host) | 50,000 | 1.50x | 2.00x | 2.50x |
| Full boss (Subroutine Core) | varies by round | 1.50x | 2.00x | 2.50x |

**Key deltas from stock**:
- Regular zombies scale **stock rate** (+100% per player).
- Elites scale **flatter** (+50% per extra player, not +100%). Elites become harder but not impossible in 4p.
- Bosses scale **flatter** (+50% per extra player). Prevents 4p boss fights from taking 20+ minutes.

Rationale: in 4p, elite / boss *density* is higher (spawns scale too), so raw HP doesn't need to be 4x. Team total DPS scales faster than solo, so flatter HP keeps pacing consistent.

## Spawn Rate Scaling

| Player count | Regular zombie spawn rate | Elite spawn rate |
|---|---|---|
| 1 | 100% | 100% (baseline = `elite_quota_for_round()` in `_acc_elites.gsc`) |
| 2 | 130% | 130% (one extra elite per round past r11) |
| 3 | 160% | 160% |
| 4 | 190% | 190% |

Scales **flatter** than HP scaling - total zombies don't quadruple in 4p, which would be chaos. 4p players are expected to clear faster individually.

## Downed / Revive Rules

- **Down state**: player HP reaches 0 from zombie damage → drop into down state (crawl with pistol).
- **Bleed-out timer**: **30 seconds** base.
  - Extended by **Subroutine Tier 2 Caching** Cyberware: 60 seconds.
  - Halved by **Bleed Out** modifier: 15 seconds.
- **Revive action**: stand over downed teammate, hold [use] for **5 seconds** base.
  - Reduced by **Quick Revive** to **2 seconds**.
- **Revive points**: 100 for the reviver (stock BO3 behavior).
- **Self-revive (solo)**: Quick Revive grants 1 self-revive per run in solo; cannot self-revive in co-op.
- **Self-revive (co-op)**: **available only via purchased self-revive** (4000 Points + 2 Data Shards at a specific vending slot; see [06_mechanics.md](06_mechanics.md#downed--revive-mechanics)). Subroutine Caching halves the Shard cost.
- **Dying**: if bleed-out expires without revive, player dies. They respawn at the start of the next round.
- **Respawn consequences**:
  - Lose all perks.
  - Keep all weapons (with their tiers + Overclocks).
  - Keep all Cyberware.
  - Keep all boss items.
  - Keep Data Shards.
  - Lose half of current Points? → **No**, kept intact. Stock BO3 "lose all points" on death is NOT applied; we keep Points as a deliberate softening.

## Friendly Fire

- **OFF by default** (zombies convention). Players cannot damage teammates with bullets / melee / grenades.
- **Exceptions**: stock BO3 has some edge cases where splash damage still applies (e.g. explosive weapons); we inherit stock behavior without custom overrides.
- **Reviving** does not count as friendly interaction in any damage sense.

## Point Economy in Co-op

See [06_mechanics.md](06_mechanics.md#co-op-kill-point-split-70--30) for full detail. Summary:

- **Regular kill**: 40 pts total. Killer gets 70% (28), non-killer damage contributors split 30% (12 total).
- **Headshot / knife kill**: 100 pts total. Killer 70% (70), others split 30% (30 total).
- **Solo kill (no other contributors)**: killer gets 100%.
- **Minimum contribution threshold**: 5% of zombie maxhealth to qualify for a share.
- **Anti-exploit rules**: documented in `_acc_points.gsc` and [06_mechanics.md](06_mechanics.md#anti-exploit-rules-hard-enforced-in-code).

## Data Shard Distribution in Co-op

- **Elite kill**: killer picks up the shard. First-come-first-served on pickup entity.
- **Shared damage on an elite**: no automatic split. Only the player who collects the pickup entity receives the Shard. Anti-grief: if one player kills the elite, they MUST move to the corpse within 30 seconds to collect, otherwise the pickup despawns and Shards are lost.
- **Boss shard grant**: independent per-player (4 Shards to every player on full boss kill, not 4 shared).
- **Objective Shard rewards** (Hack, Vault Overload): go to the player who activated and saw the event through. In 4p, if 3 players help but one player activated the Hack, only the activator gets the 2 Shards.

## Boss Item Drops in Co-op

- **Mini-boss** (50% drop chance): 1 item drops at boss corpse. Any player can pick up.
- **Full boss** (100% drop chance): 1 item drops at boss corpse.
- **Duplicate detection is per-player.** If player A has Neural Boots already and they pick up a dropped Neural Boots, it converts for them. Player B without Neural Boots walking up gets a fresh Neural Boots equipped.
- **Pickup priority**: first player within 64u of the item pickup wins.
- **Team coordination**: in 4p, a single item drop can only go to one player. Expect teams to coordinate boss-kill approach so the "right" player (based on build needs) can claim the item.

## Weapon & PaP in Co-op

- **Mystery Box**: standard BO3 behavior. Any player can roll (costs 950 Points). Only the rolling player gets the weapon.
- **Pack-a-Punch**: each player buys their own PaP levels for their own weapons. No sharing.
- **Overclock Terminal / Tiers**: each player buys their own tiers for their own weapons.
- **Wallbuys**: each player pays individually.

## Side Event Behavior in Co-op

### Hack Terminal

- **One activation per run** (or two with Parallel Processing Cyberware).
- **Activator**: the player who holds F first wins the activation.
- **Other players can help** during the 3 stages (their kills count toward the stage counter).
- **Reward**: 2 Data Shards go to the **activator only**. (Note: this is the one place where the 70/30 split does NOT apply - Shard rewards from events are activator-gated.)

### Vault Overload

- **One activation per run** (or two with Parallel Processing).
- **Activator**: the player who holds F first wins.
- **The activator must stay on the point**. Other players can roam, help with waves, kite adds.
- **Point defense tether**: the activator leaving the point > 8s cumulative fails the event. Other players leaving have no effect.
- **Reward**: 3 Data Shards + map shortcut go to the **activator only** (shortcut unlock IS map-wide).

## Emergency Drop in Co-op

- Any player can activate at a power switch (spend 3 of their own Shards).
- Drop type is random (same table as solo).
- Drop pickups (e.g. Max Ammo): team-wide benefit (stock behavior). Insta-Kill applies team-wide.
- Strategic use: 4p teams can have one player stockpile Shards for emergency drops while others invest in weapons.

## Mule Kick Interaction

- **Mule Kick** = 3rd primary weapon slot (**2,500 Points** on this map).
- **Per-player**. Each player buys their own.
- If a player loses Mule Kick (dying through respawn), the 3rd weapon reverts to the floor and can be picked up again by repurchasing Mule Kick at a machine.

## 4-Player "Easy Mode" Fact

4p co-op is intentionally the easiest configuration:

- Boss fights: 4x damage output, 2.5x boss HP → ~60% time.
- Elite pressure spread across 4 players.
- 4 independent Shard pickups per elite.
- 4 boss items per boss kill (up to 2 per player, extras convert to Shards).
- Rapid power switch flip and perk-buying.

Solo is the hardest configuration. **This is intentional.** Zombies is a co-op genre; solo is an option, not the default.

## Known Co-op Gotchas

- **Host migration**: if the host disconnects, run ends. Stock BO3 doesn't support mid-run migration in zombies.
- **Join-in-progress**: limited support. A player joining mid-run spawns with default loadout at the start of the next round. They do NOT inherit the host's weapons / tiers / Shards. They start fresh.
- **Desync**: rare but possible in long runs (2+ hours). Our systems all run server-side (GSC), so clients should stay in sync for gameplay state; HUD can occasionally drift (LUI issue, not GSC).

## Implementation Status

- Stock co-op: works out of the box via the zm template.
- HP / spawn-rate scaling: needs to hook into `_zm.gsc` round logic. Scaffolded but not fully tuned.
- Per-player state: correctly isolated in all our modules (grep `self.acc_*` in scripts/).
- Boss item per-player duplicate detection: implemented in `_acc_boss_items.gsc::on_boss_death`.
- Side-event activator-gating: implemented in `_acc_events_hack.gsc` and `_acc_events_overload.gsc`.

## Tuning Levers

- **Elite HP in 4p**: 2.5x may still be too much if bullet-sponge feeling kicks in. Lower to 2.0x in playtest.
- **Boss HP in 4p**: 2.5x can feel either about right or too short depending on comp. Adjust per playtest.
- **Spawn rate multipliers** (130/160/190%): the 190% in 4p may be chaos; consider 170%.
- **Shard rewards in 4p**: if players feel they progress too fast in 4p, consider reducing boss per-player Shard award (4 → 3) in 4p specifically.
