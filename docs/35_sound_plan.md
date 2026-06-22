# 35 — Sound & Music Plan (atmosphere audio, gameplay reads, music)

> **Design + implementation spec for the map's *audio*.** The map is effectively
> silent today (5 stock `PlaySound` calls, no ambient bed, no music, no reverb).
> This doc is the authoritative plan for adding a **legible, atmospheric,
> Workshop-shippable** soundscape. It pairs with the *look* spec
> [29 — Atmosphere & Materials](29_atmosphere_and_materials.md) (which has a short
> Soundscape pointer back here) and the portable pipeline notes in
> [BO3_MAPMAKING_KB.md](BO3_MAPMAKING_KB.md). Licensing follows
> [CLAUDE.md](../CLAUDE.md) / [CREDITS.md](../CREDITS.md): **ship only stock,
> self-authored, or CC0 audio.**

**Status (2026-06-15):** research complete + **adversarially verified** (10-agent
workflow). **Build-safe Phase A scaffold landed** (code, not audio): the alias
table `sound/aliases/acc_audio.csv` (header only), the dvar-gated **ambient bed**
in `_acc_atmosphere.gsc`, the **decon alarm** cue, and the **Data-Shard pickup**
cue are wired. Every cue is a **silent no-op until its alias + WAV exist**, and the
`.szc` is intentionally untouched, so the tree still builds clean (`lint_gsc_xref`
green). To make sound audible, follow the **go-live checklist in §8** (download CC0
WAVs → paste rows → add one `.szc` line → build). Remaining cues (UI, elite/boss
reads, events, music) are unwired and mapped in §8.

**Scope stance:** the project de-prioritizes art/sound ("make it legible, not
beautiful" — [docs/08:102](08_milestones.md)). So audio earns its keep by making
**gameplay readable first** (elite offscreen reads, event cues), mood second.

---

## 1. Where we are today (verified)

Wired audio = **5 `PlaySound` calls, all stock aliases, zero custom assets**:

| Call | Alias | Status |
|---|---|---|
| [_acc_pap_levels.gsc:211,242,269,279](../scripts/zm/zm_abandoned_cyber_city/_acc_pap_levels.gsc#L211) | `zmb_perks_packa_deny` / `zmb_perks_packa_ready` | ✅ stock, valid |
| [_acc_mega_bottles.gsc:420](../scripts/zm/zm_abandoned_cyber_city/_acc_mega_bottles.gsc#L420) | `evt_bottle_dispense` | 🚫 **defined nowhere → plays silent** (the one real bug) |

The sound-zone config [sound/zoneconfig/zm_abandoned_cyber_city.szc](../sound/zoneconfig/zm_abandoned_cyber_city.szc)
declares **4 Sources**:

| Source | Type | In repo? | Verdict |
|---|---|---|---|
| `acc_skye_box_weapons.csv` | ALIAS | ✅ (67 weapon-port SFX rows) | game-rip wavs — gitignored, **NOT publish-cleared** |
| `nsz_brutus.csv` | ALIAS | ✅ (18 Brutus boss SFX rows) | game-rip wavs — gitignored, **NOT publish-cleared** |
| `user_aliases.csv` | ALIAS | ❌ not in repo | **OK as-is** — it's the *stock starter* CSV in the Mod Tools (`share/raw/sound/aliases/user_aliases.csv`, holds `test_sound` + the `UIN_MOD` template; **verified present on this install**). Referencing it is normal; it just carries none of our content. |
| `ambient_mod.csv` | AMBIENT (`mpl_mod`) | ❌ not in repo | **OK as-is** — stock reverb/ambient-room table in the Mod Tools (`share/raw/sound/ambients/`). Every shipped ZM usermap references this exact block. Keep it. |

So only **one** thing is actually broken (`evt_bottle_dispense` is silent); the two
"missing" CSVs are stock files that resolve from the tools install, not bugs.

Other facts:
- [_acc_atmosphere.gsc](../scripts/zm/zm_abandoned_cyber_city/_acc_atmosphere.gsc) is **fog-only** (`SetVolFog`); no audio.
- [_acc_boss.gsc](../scripts/zm/zm_abandoned_cyber_city/_acc_boss.gsc) has **zero** sound calls.
- The zone manifest wires audio correctly with one line: `sound,zm_abandoned_cyber_city` ([zone:33](../zone_source/zm_abandoned_cyber_city.zone)). You do **not** list CSVs/wavs individually.
- `.szc` is `IsProduction:false`, `IsShipped:false`, `GameMode:"mpl"` — a dev sound zone, flip to production only when the bank builds clean for ship.
- The decontamination warning ([docs/20:130](20_requirements_checklist.md)) is marked implemented but ships **text-only** (`iprintlnbold`) — its **audio half is deferred**.
- All **6 enemy/boss audio reads** are tracked `phase4-blocked` and unbuilt (see §2).

---

## 2. The atmosphere target — what it should *sound* like

Fiction ([docs/29 §1](29_atmosphere_and_materials.md), [docs/00](00_overview.md)):
a **dead high-tech city** — perpetual rainy neon night, dead/flickering signage,
smog, wet reflective ground, decay over chrome; low-key noir à la Shadows of Evil /
Blade Runner 2049 / Cyberpunk 2077 derelict districts. The neon palette maps to
audio: **cyan** = live tech (hums, beeps), **magenta** = dead nightlife (distant
muffled music, silence), **amber** = dying power (electrical buzz, flicker crackle).

Target soundscape, by priority:

1. **Gameplay reads (highest value — these are *legibility*, not decoration).**
   The design *requires* every elite to be **audibly distinguishable offscreen in
   ~1 s** ([docs/11:9,52,129](11_enemies.md)):
   - **Shielded** = metallic **CLANK** (looping on the actor).
   - **Teleporter** = **CRACK** played at **both** source and destination origins.
   - **EMP** = continuous **HUM** (loop on actor, stops on death).
   - **Mini-boss** (Juggernaut Host, r10/r20) = **pre-spawn siren + ground rumble**
     so players reposition before it lands ([docs/11:65,130](11_enemies.md)).
   - **Full boss** (Subroutine Core, r30+) = looping **low-frequency drone ONLY
     while the Lab fight is active** — silence otherwise, for contrast ([docs/11:131](11_enemies.md)).
2. **Event / UI cues.** Decontamination round-start alarm/klaxon ([docs/03:106](03_layout.md));
   Data-Shard pickup blip; Cyberware confirm/deny; Overclock activation jingle;
   kiosk/terminal clicks; insufficient-funds error; Hack/Overload success/fail/
   timeout stingers; Emergency Drop cue.
3. **Ambient bed (per zone).** Low rain/wind hiss, distant city drone, intermittent
   electrical buzz/spark, dripping water. **Dim undercity** = quieter/lower; **bright
   plaza** = faint dead-neon hum. Reverb: wet/cavernous undercity vs flatter plaza
   ([docs/08:107](08_milestones.md)).
4. **Music (lowest priority, conditional).** Optional dark-electronic round-transition
   bed + a single signature theme / easter-egg song, "if trivial; otherwise stock."

---

## 3. Asset sourcing & licensing (the gate)

A BO3 `.ff` stores **raw, trivially-extractable audio**, so the only
unambiguously-shippable categories are **stock / self-authored / CC0**
([CLAUDE.md](../CLAUDE.md), mirrors [docs/29 §8](29_atmosphere_and_materials.md)).

### 3a. icegrenade.co.uk — 🚫 NOT for a public ship (verified)

The site the owner pointed at (`icegrenade.co.uk/assets/`) is **IceGrenade/ZGC's
"Asset Finder" — a link *index*, not an asset host.** Verified independently:

- Its **Terms of Service expressly prohibit redistribution** ("You may not
  redistribute… any Site content"; "Third-party assets… remain property of their
  creators").
- **~95% of its audio is ripped** ("ported") from official Activision/Treyarch
  games (Alpha Omega / Die Maschine round sounds, Dr. Monty & announcer vox, Dark
  Aether perk jingles) or *other* games (Battlefield 1, Jurassic Park). Credited
  names are **porters, not rights-holders**.
- Bundling these in a public Workshop `.ff` violates the Steam Subscriber Agreement
  (§6.D warranty of ownership/rights) and the project's own CC0-only rule.
- There are **zero dedicated ambience/environmental-loop packs** on the index
  anyway — a real gap for a cyberpunk bed.

**Verdict: local playtest ONLY; never in the published map.** This is the same
class as the existing `_NSZ`/`skye_ports` packs already flagged IP-review-pending.
Treyarch-origin ports are the tolerated grey area the custom-zombies scene runs on
*in-engine*; third-party-game audio (BF1/Jurassic Park) is unambiguously
infringing. Source nothing shippable here.

### 3b. CC0 packs to use instead (verified genuinely CC0 — no attribution, commercial OK, bundle-safe)

| Pack | Covers | Link |
|---|---|---|
| **Kenney — Sci-fi / Digital / UI Audio** | UI clicks, shard/perk pickups, robotic/EMP blips | `kenney.nl/assets/sci-fi-sounds` (+`/digital-audio`, `/ui-audio`) |
| **Tallbeard — Free Music Loop Bundle (Abstraction)** | round/EE music bed (pick dark/electronic) | `tallbeard.itch.io/music-loop-bundle` |
| **OpenGameArt — Joth "Ambience Pack 1: Sci-Fi Horror"** | abandoned-facility room tones / ambient bed | `opengameart.org/content/ambience-pack-1-sci-fi-horror` |
| **OpenGameArt — Joth "Cyberpunk Moonlight Sonata"** | signature theme / PaP-room track | `opengameart.org/content/cyberpunk-moonlight-sonata` |
| **ObsydianX — Interface SFX Pack 1** | full kiosk/menu UI set (confirm/back/cursor/error) | `obsydianx.itch.io/interface-sfx-pack-1` |
| **Kronbits — 200 Free SFX** | alarms, lasers, electric (boss/EMP/decon) | `kronbits.itch.io/freesfx` |
| **Freesound — CC0 filter ONLY** | bespoke boss low-freq drones, sirens, teleport whoosh, machinery | `freesound.org` → set license filter = *Creative Commons 0* |

**Do NOT use as-listed (license traps caught in verification):**
- 🚫 **ROT: Horror Audio Bundle** is actually **paid** (~€9.97) + ships an unread
  license PDF. Dropped. Use Joth ambience + Tallbeard instead.
- ⚠️ **OpenGameArt "CC0 Sound Effects" (OwlishMedia)** is a **mixed-license
  *collection*** — at least one sub-item ("8-Bit Sound Effect Pack") ships a
  no-resale `License.txt` that is NOT CC0. Prefer rubberduck's single
  "100 CC0 SFX" submissions, vetted per item.
- ⚠️ **Pixabay / Sonniss / Patrick de Arteaga (CC-BY)** prohibit standalone
  redistribution or require attribution → grey-area inside a `.ff`. Prototype only.

**Golden rule:** the binding license is the storefront tag **AND** any
`License.txt`/PDF inside the downloaded zip (the OwlishMedia case proves a CC0
storefront tag can be contradicted by a bundled file). **Log every source — even
CC0 — in [CREDITS.md](../CREDITS.md) before going Public.**

---

## 4. BO3 sound pipeline (how to implement — repo already scaffolded)

Four authored layers feed **one** build step. Verified against local stock scripts,
3 shipped community usermaps, and the live tools install.

1. **WAV spec: 48000 Hz, 16-bit PCM (Microsoft signed).** Wrong rate/depth is the
   #1 silent-failure cause. **2D vs 3D is the alias `Pan` column, NOT channel count**
   — both mono and stereo are accepted (stock uses stereo on `3d` rows).
2. **Place the WAV** under the Mod Tools `sound_assets/<folder>/` (e.g.
   `sound_assets/acc/ui/`). The CSV `FileSpec` is **relative to `sound_assets/`**
   (verified vs the existing `_NSZ\` and `skye_ports\` paths).
3. **Alias row** in a `sound/aliases/*.csv` — copy the 102-column header from
   [nsz_brutus.csv](../sound/aliases/nsz_brutus.csv). Load-bearing columns:
   `Name` (the GSC string), `FileSpec`, `Template=UIN_MOD` (fills ~90 blank cells),
   `Bus=BUS_FX` (sfx/ambience) or `BUS_MUSIC`, `Pan=2d` (headlocked/UI/music) or
   `3d` (positional), `Looping=LOOPING|NONLOOPING`, `DistMin/DistMaxDry/DistMaxWet`
   (3D falloff). For music also `IsMusic=1`, `Pan=2d`, and (advisory, not required)
   `Storage=STREAMED` for long tracks.
4. **Register the CSV** as an `ALIAS` Source in the `.szc`. The `AMBIENT`
   `ambient_mod` block stays as-is (stock).
5. **Zone manifest** already has `sound,zm_abandoned_cyber_city` — leave it.
6. **Build:** there is **no standalone sound exe** — the same Launcher/`linker_modtools.exe`
   pass that compiles GSC compiles the `.szc` into `sound/zone/*.all.*.sz` +
   `CachedBanks/{all,english}/<map>.{sabl,sabs}` banks. ⚠️ **A GSC-only relink
   reuses STALE soundbanks**, and the linker builds the **DEPLOYED usermap copy** →
   run `tools/sync_to_modtools.ps1` first and make sure the wavs are in the tools
   `sound_assets/` tree.

**Playback idioms (server `.gsc`):**
- One-shot positional: `ent PlaySound("alias")` / `PlaySoundAtPosition("alias", origin)`.
- 2D to all players: `zm_utility::play_sound_2D("alias")` (alias `Pan=2d`).
- Looping point emitter: flag the alias `LOOPING`, then
  `sound::loop_in_space("alias", origin, "ender")` or `ent sound::loop_on_entity("alias")`;
  stop with `StopLoopSound()` / notify the ender. Must anchor to a real entity/origin.
- **Music:** name aliases `mus_<state>_intro` (the engine plays exactly that name).
  `level zm_audio::musicState_Create("acc_<state>", PLAYTYPE_SPECIAL, "<state>")`,
  play `level thread zm_audio::sndMusicSystem_PlayState("acc_<state>")`, stop
  `sndMusicSystem_StopAndFlush()` + `music::setmusicstate("none")`. The EE-song
  hooks (`sndMusicSystem_EESetup/EEWait`) are **empty stubs** — hand-roll the trigger.

**Reverb is BSP-driven, NOT scriptable server-side.** Place Radiant `trigger_multiple`
volumes (`targetname ambient_room`, `script_ambientroom <stock room>`,
`script_ambientpriority`, **CLIENTSIDE_TRIGGER** checked) → the engine fires
`CodeCallback_SoundSetAmbientState` → `forceambientroom` on the **client**. Room
names resolve through stock `ambient_mod.csv` to reverb presets in
`share/raw/sound/reverb/common_reverb.csv` (e.g. `global_urban_outdoor`,
`factory_largeroom`). A server `_acc_*.gsc` **cannot** set reverb (separate VM;
`.csc` can't call `.gsc`). Per-zone reverb therefore forces a full
`cod2map64`+LED+linker build (success marker: `<map>.ambientgeometry.json` appears).

---

## 5. Phased work plan

Each task names the file(s) to touch and the build kind. (Lightweight tracking
mirror of the [docs/20](20_requirements_checklist.md) `phase4-blocked` audio items.)

### Phase A — Quick wins (linker-only, no Radiant, no geometry rebuild)
- **A1 — Resolve the silent alias.** Define `evt_bottle_dispense` in the new
  `acc_audio.csv` (or repoint [_acc_mega_bottles.gsc:420](../scripts/zm/zm_abandoned_cyber_city/_acc_mega_bottles.gsc#L420)
  to a real stock alias as interim). *Confirm on Windows whether it errors the
  sound build or just silently misses.* Keep `user_aliases`/`ambient_mod` as-is.
- **A2 — Author the core CC0 UI/SFX alias set** → new `sound/aliases/acc_audio.csv`
  + `sound_assets/acc/{ui,event}/` wavs; register as an `ALIAS` Source in the `.szc`.
  Aliases: `acc_shard_pickup`, `acc_cyber_confirm`, `acc_cyber_deny`,
  `acc_overclock_activate`, `acc_kiosk_click`, `acc_buy_error`, `acc_decon_alarm`,
  `evt_bottle_dispense`.
- **A3 — Wire UI/event SFX into systems code** — Data-Shard gain, Cyberware
  confirm/deny, Overclock activate, kiosk clicks + insufficient-funds, and the
  **decontamination alarm** (fills the deferred audio half of `decon-hud-audio-warning`).
  Files: `_acc_data_shards.gsc`, `_acc_cyberware.gsc`, `_acc_overclocks.gsc`,
  `_acc_ui.gsc`/`_acc_perk_info.gsc`, `_acc_decontamination.gsc`.
- **A4 — Single global ambient bed** — one `LOOPING` CC0 city/rain drone started
  from [_acc_atmosphere.gsc](../scripts/zm/zm_abandoned_cyber_city/_acc_atmosphere.gsc)
  after the `initial_blackscreen_passed` flag (same hook the fog loop uses). First
  audible mood layer; no Radiant needed.

### Phase B — Per-zone soundscape + reverb (needs a FULL BSP build)
- **B1 — Per-zone ambient loops** (mood-matched: undercity quiet/low, plaza dead-neon
  hum). Script `sound::loop_in_space` per zone struct, or Radiant emitter entities.
- **B2 — Per-zone reverb** via Radiant `ambient_room` volumes → stock presets.
  `map_source/zm/zm_abandoned_cyber_city.map`. Forces `cod2map64`(cwd=`bin`)+LED+linker.

### Phase C — Gameplay audio reads + event stingers (clears the `phase4-blocked` items)
- **C1 — Elite offscreen reads** (Shielded clank loop / Teleporter crack at source+dest /
  EMP hum loop). `_acc_elites.gsc`.
- **C2 — Mini-boss pre-spawn siren + ground rumble.** `_acc_boss.gsc` (`run_mini_boss`).
- **C3 — Lab full-boss looping low-freq drone** (only while fight active). `_acc_boss.gsc`
  (`run_full_boss` / `release_lab_exits` / boss death).
- **C4 — Event stingers** (Hack/Overload success/fail/timeout, Emergency Drop).

### Phase D — Music (lowest priority, conditional)
- **D1 — Round-transition music bed** via the `zm_audio` music-state system
  (`mus_acc_round_intro`, watch `PLAYTYPE` precedence so it doesn't fight round music).
- **D2 — Signature theme + optional 3-object easter-egg song** (Radiant trigger/model
  trios + GSC counter; hand-rolled since the EE hooks are stubs).

---

## 6. Risks & open questions (verify on the Windows box)

**Licensing (highest risk):**
- The existing `acc_skye_box_weapons.csv` + `nsz_brutus.csv` point at game-rip wavs
  — **not publish-cleared**. Do **not** extend them; all new audio must be CC0/self-authored.
- Never flip the Workshop item Public until [CREDITS.md](../CREDITS.md) lists every
  audio source and the IP review passes. icegrenade/ported audio fails this gate.
- Re-check each CC0 download's in-zip `License.txt`/PDF before bundling.

**Build-tool gotchas:**
- Sound changes need a build pass that **re-runs the sound stage** — a GSC-only
  relink reuses stale `.sabl/.sabs`. If a sound won't update, delete cached banks in
  `usermaps\…\zone\snd\` and rebuild.
- Linker builds the **deployed** copy → `sync_to_modtools.ps1` first.
- One bad/missing wav referenced in a CSV can **abort the whole sound build** →
  comment the row with `#` on the `Name` to isolate.
- **WAVs MUST be 48 kHz** (16-bit PCM). A non-48k wav is a hard linker error —
  `ERROR: <wav> / wav is not 48k sample rate` (non-fatal: the `.ff` still packs, but the
  sound won't load). No ffmpeg on the box → resample with **no dependencies** via the Node
  2× frame-duplication upsampler used for `acc_overclock_zap` (24k→48k, same pitch/length;
  see CHANGELOG 2026-06-21). For pristine quality re-export the source at 48k instead.
- **The soundbank `.sabs` is file-locked while the game is RUNNING** → even a sound-stage
  build reuses the stale bank (sync can't delete the locked `CachedBanks`), so a new/changed
  sound **does not compile until a GAME-CLOSED build**. Symptom: alias is valid, no linker
  error, yet the cue is silent. Close BlackOps3, then `build_map.ps1`.
- Live aliases: `acc_amb_city_bed`, `acc_main_theme`, `acc_brutus_music`, `acc_glitch_warp`,
  `acc_overclock_zap` (overclock kiosk zap, 2026-06-21). Others `PlaySound`'d in GSC
  (`acc_shard_pickup`, `evt_bottle_dispense`, …) have **no alias row yet** → silent.
- Reverb (B2) requires the heavier geometry build, not a linker-only pass.
- Decon LUI widget + any client `forceambientroom` are `.csc`-only (need L3akMod;
  can't call `.gsc`).

**To verify on Windows (TODO):**
1. Does the current build succeed and does `evt_bottle_dispense` error or silently
   miss? (Drives A1's exact fix.)
2. Confirm stock `ambient_mod.csv` / `common_reverb.csv` exist on this install and
   which `mpl_mod` reverb rooms are available (for B2 room names).
3. Decide music `PLAYTYPE` precedence before D1 (`PLAYTYPE_ROUND` can block zone music).

---

## 7. Decisions / cross-links

- **Owning doc:** this file (35) owns audio direction; [docs/29 §15](29_atmosphere_and_materials.md)
  carries a one-paragraph pointer here (audio was previously scattered across
  docs/08 and docs/11).
- **Locked:** icegrenade = local-only; shippable audio = CC0/self-authored only;
  gameplay reads (Phase C) outrank mood (B) and music (D) in value.
- Full agent research dossier (icegrenade ToS, per-pack license verdicts, pipeline
  evidence) lives in the workflow transcript; verified facts are distilled here.

---

## 8. Implementation status & go-live checklist

### 8a. What's wired now (build-safe scaffold, 2026-06-15)

**Update (2026-06-15):** the **ambient bed** and **main theme** are now LIVE — their
WAVs are placed (48k/16-bit) and `acc_audio.csv` **is** registered in the `.szc`
(pending a Launcher Compile to build the soundbank). **Stock zombies music is
disabled** (`init()` sets `level.bonuszm_musicoverride = true`). The remaining cues
are **silent no-ops until their alias + WAV exist** (a missing alias never errors a
build — proven by the long-silent `evt_bottle_dispense`); adding a row + WAV is all
that's left for each.

| Cue | Alias | Where wired | Pan / Loop |
|---|---|---|---|
| Global ambient bed ✅ LIVE | `acc_amb_city_bed` | [_acc_atmosphere.gsc](../scripts/zm/zm_abandoned_cyber_city/_acc_atmosphere.gsc) `apply_ambient_bed()`, dvar `acc_amb_on` (default 0) | 2d / **LOOPING** |
| Main theme ✅ LIVE — once at start; stock music OFF | `acc_main_theme` | [_acc_atmosphere.gsc](../scripts/zm/zm_abandoned_cyber_city/_acc_atmosphere.gsc) `apply_music()`, dvar `acc_music_on` (default 1) | 2d / IsMusic |
| Decontamination alarm | `acc_decon_alarm` | [_acc_decontamination.gsc](../scripts/zm/zm_abandoned_cyber_city/_acc_decontamination.gsc) `run_seal_phase()` (the EVACUATE warning) | 2d / one-shot |
| Data-Shard pickup | `acc_shard_pickup` | [_acc_data_shards.gsc](../scripts/zm/zm_abandoned_cyber_city/_acc_data_shards.gsc) `watch_pickup()` (physical claim only) | 3d-on-player / one-shot |
| Mega-bottle dispense (pre-existing call) | `evt_bottle_dispense` | [_acc_mega_bottles.gsc:420](../scripts/zm/zm_abandoned_cyber_city/_acc_mega_bottles.gsc#L420) (unchanged) | 3d / one-shot |

### 8b. Go-live checklist (make it audible)

1. **Download + convert.** Grab the CC0 source per alias (table below), convert each
   to **48000 Hz, 16-bit PCM WAV** (Audacity: set project rate 48000 → Export WAV →
   "Signed 16-bit PCM"). One clip per alias.
2. **Place WAVs** in the Mod Tools at the `FileSpec` path (relative to
   `sound_assets/`): `sound_assets/acc/ui/`, `/event/`, `/amb/`.
3. **Paste rows** into [sound/aliases/acc_audio.csv](../sound/aliases/acc_audio.csv)
   (these mirror the exact 102-column layout of `acc_skye_box_weapons.csv` — only
   `Name`, `FileSpec`, `VolMin/Max`, `PanType`, and `Looping` differ):
   ```
   acc_amb_city_bed,,,acc\amb\city_bed.wav,,,UIN_MOD,,,,,BUS_FX,,,,,,65,70,,,,,,,,,,,,,,,,,,,2d,,,LOOPING,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
   acc_decon_alarm,,,acc\event\decon_alarm.wav,,,UIN_MOD,,,,,BUS_FX,,,,,,85,90,,,,,,,,,,,,,,,,,,,2d,,,NONLOOPING,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
   acc_shard_pickup,,,acc\ui\shard_pickup.wav,,,UIN_MOD,,,,,BUS_FX,,,,,,80,85,,,,,,,,,,,,,,,,,,,2d,,,NONLOOPING,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
   evt_bottle_dispense,,,acc\event\bottle_dispense.wav,,,UIN_MOD,,,,,BUS_FX,,,,,,80,80,0,1000,1000,,,,,,,,,,,,,,3d,,,NONLOOPING,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
   ```
4. **Register the CSV** — add this Source block to
   [sound/zoneconfig/zm_abandoned_cyber_city.szc](../sound/zoneconfig/zm_abandoned_cyber_city.szc),
   alongside the existing ALIAS blocks (before the `ambient_mod` AMBIENT block):
   ```json
   {
    "Type" : "ALIAS",
    "Name" : "acc_audio",
    "Filename" : "acc_audio.csv",
    "Specs" : [ ]
   },
   ```
5. **Build.** `tools/sync_to_modtools.ps1` (linker builds the *deployed* copy), then
   a full Launcher/linker build (the GSC pass also builds the soundbank — a GSC-only
   relink reuses stale `.sabl/.sabs`). One bad/missing WAV aborts the sound build →
   isolate by removing the offending row.
6. **Hear it.** Ambient bed: `set acc_amb_on 1` in console. Pick up a shard; trigger
   a rounds-1–4 decontamination. Log every source in [CREDITS.md](../CREDITS.md).

### 8c. WAV → recommended CC0 source (specific files, licenses confirmed on-page 2026-06-15)

| Alias | Exact pick | URL | License |
|---|---|---|---|
| `acc_amb_city_bed` | Joth — *Infestation in the Control Room.mp3* (~1:00, loopable; in "Ambience Pack 1: Sci-Fi Horror") | `opengameart.org/content/ambience-pack-1-sci-fi-horror` | CC0 |
| `acc_decon_alarm` | pointparkcinema — *Alarms.wav* (5.8 s klaxon, trim to ~2 s) | `freesound.org/people/pointparkcinema/sounds/407240/` | CC0 |
| `acc_shard_pickup` | Samuel54tw — *Pickup_Coin* (0.4 s digital blip) | `freesound.org/people/Samuel54tw/sounds/705735/` | CC0 |
| `evt_bottle_dispense` | courter — *Soda Machine Bottle Drop* (22 s; trim to the ~1 s drop) | `freesound.org/people/courter/sounds/448673/` | CC0 |

**Fastest path (2 downloads, no account, no trimming):** Joth ambience pack (OpenGameArt,
direct file links → covers the bed) + **Kronbits "200 Free SFX"**
(`kronbits.itch.io/freesfx`, CC0 "no credit needed", direct zip → has alarms/blips/clunks
covering the alarm + shard pickup + bottle dispense). Kenney "Digital Audio" /
"Sci-fi Sounds" (`kenney.nl/assets/digital-audio`, CC0 direct zip) are good blip alternates.
**Freesound needs a free account** and is mixed-license — the three files above were each
confirmed "Creative Commons 0" in their own license box (not just the search filter).

### 8d. Next wiring pass (unwired — exact hook sites)

Each is a one-line `PlaySound`/`play_sound_2D` at the named site once the alias
exists (all build-safe — silent until authored):

| Alias(es) | Hook site | Phase |
|---|---|---|
| `acc_cyber_confirm` / `acc_cyber_deny` | `_acc_cyberware.gsc` (purchase confirm / insufficient shards) | A |
| `acc_overclock_activate` | `_acc_overclocks.gsc` (overclock applied) | A |
| `acc_kiosk_click` / `acc_buy_error` | `_acc_ui.gsc` / `_acc_perk_info.gsc` (interaction / deny) | A |
| `acc_elite_shield_clank` / `acc_elite_tele_crack` (src+dest) / `acc_elite_emp_hum` | `_acc_elites.gsc` (promotion / ability loops) | C |
| `acc_miniboss_siren` / `acc_miniboss_rumble` | `_acc_boss.gsc` `run_mini_boss` (pre-spawn) | C |
| `acc_boss_drone` | `_acc_boss.gsc` `run_full_boss` start / `release_lab_exits` stop | C |
| `acc_event_success` / `_fail` / `_timeout` | `_acc_events_hack.gsc` / `_acc_events_overload.gsc` | C |
| `acc_emergency_drop` | `_acc_emergency_drop.gsc` | C |
