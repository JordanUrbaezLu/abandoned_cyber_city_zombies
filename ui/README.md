# ui/

LUI (Lua UI) source files will live here when we reach Phase 4 (see [docs/08_milestones.md](../docs/08_milestones.md)).

Deferred until:
- Data Shard HUD widget (simple number + icon, reads `clientfield acc_data_shards`).
- Cyberware skill-tree screen (grid of 9 nodes, shows affordability, mutual exclusion lockouts).
- Modifier selection screen (optional; can ship with dvar-based toggles).

Until then this folder is intentionally empty. Our scaffolded GSC writes to `iprintln` text instead of LUI, which is sufficient for Phase 3 playtesting.
