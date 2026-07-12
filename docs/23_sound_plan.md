# 23 — Sound & Music Reference (aliases, per-event map, pipeline)

> **The living reference for the map's *audio*.** Not a pre-build plan anymore — the
> map is fully built and ships a real soundscape (music channel, perk jingles,
> pickup/economy SFX, boss + Paradise anthems, round stingers). This doc is the
> single place to see **what plays today, what's still silent, and how to add a
> cue.** It pairs with the *look* spec [29 — Atmosphere & Materials](20_atmosphere_and_materials.md)
> and the portable pipeline notes in [BO3_MAPMAKING_KB.md](BO3_MAPMAKING_KB.md).
> Licensing follows [CLAUDE.md](../CLAUDE.md) / [CREDITS.md](../CREDITS.md): **ship
> only stock, self-authored, or CC0 audio** (see §4).

**Status (2026-07-10):** a large custom alias set is **LIVE** in
[`sound/aliases/acc_audio.csv`](../sound/aliases/acc_audio.csv) (47 alias rows) +
[`acc_round_sounds.csv`](../sound/aliases/acc_round_sounds.csv) (round stingers) +
the boss/weapon packs. The one-song-at-a-time **music channel** ([`_acc_music.gsc`](../scripts/zm/zm_abandoned_cyber_city/_acc_music.gsc))
governs every *song*. Perk jingles, pickups, PaP, decon alarm, powerup drop/grab,
and round-change stingers all play today. What remains silent is mostly **stock
prefab SFX** (mystery box, doors, power switch, revive, announcer VO) and a set of
**event/boss telegraph** cues that have no `PlaySound` call yet — mapped in §6.

**Scope stance:** audio earns its keep by making **gameplay readable first** (elite
reads, event cues), mood second.

---

## 0. The rule that makes the whole map work (READ FIRST)

**This is a STANDALONE usermap sound zone.** Stock aliases (`zmb_*`, `evt_*`,
`vox_*`, `mus_*`) are **UNDEFINED here by default**, so any `PlaySound("zmb_...")` /
`PlaySound("evt_...")` — in our code *and* inside the stock prefab / box / perk /
PaP / door / laststand flows we don't own — is a **SILENT no-op** at runtime unless
we give that exact alias a row in one of our CSVs. Two ways to make a call audible:

- **Our own name** — the call already uses an `acc_*` alias (`acc_shard_pickup`,
  `acc_decon_alarm`): just add the CSV row, the call starts working.
- **Stock-named override** — a stock script calls `PlaySound("evt_bottle_dispense")`
  or `PlaySound("zmb_spawn_powerup")` that we can't edit. Add a row **named exactly
  that stock alias** to `acc_audio.csv`; the linker packs it into our zone and the
  stock call resolves. This is the only lever for stock-driven SFX from our side.
  We already do this for `zmb_spawn_powerup`, `zmb_powerup_grabbed`, `evt_nuke_flash`,
  `zmb_perks_packa_{upgrade,ready,deny}`, `evt_bottle_dispense`, `evt_perk_deny`.
  (Verify per-alias; some stock SFX are viewmodel-anim notetracks we can't reach.)

---

## 1. What's LIVE today (verified against `acc_audio.csv` + code)

### 1a. The single music channel — [`_acc_music.gsc`](../scripts/zm/zm_abandoned_cyber_city/_acc_music.gsc)

**One song at a time, ever.** Every *song* source routes through `acc_music::play(alias, looping)`,
which **hard-stops** whatever is playing (Delete the owned emitter — no fade, no
overlap) and starts the new one. `zm_utility::play_sound_2D` gives no handle back, so
it can't be stopped to make room for the next song — the channel OWNS its emitter so
`play()`/`stop()`/`stop_if()` can. Reach-all in coop uses the proven idioms
(`PlaySoundWithNotify` on a `script_origin` for one-shots, `PlayLoopSound` for loops).
Call `acc_music::init()` once from [`_acc_main.gsc:170`](../scripts/zm/zm_abandoned_cyber_city/_acc_main.gsc#L170).

Sources routed through the channel (never overlap): **main theme**
(`_acc_atmosphere::apply_music`), **boss music** (`_acc_boss::boss_music`), **jukebox**
(`_acc_jukebox`, replaced the 3 EE-song teddy bears 2026-07-09), **Paradise calm + 115
anthem** (`_acc_paradise`). *Deliberately NOT routed:* perk jingles (`acc_jingle_*`)
and the ambient city bed (`acc_amb_city_bed`) — those are SFX/ambience meant to layer
*under* the music.

> **Boss-music old-fade note (superseded):** the boss track's historical 4 s fade-out
> is intentionally dropped in favour of the channel's no-overlap hard stop.
> `boss_music()` is refcounted (multi-boss safe) and, by design, is called **only by
> the Phantom** (the map's designated "real boss"); the generic ~round-10 boss does
> *not* trigger it ([`_acc_boss.gsc:289,315`](../scripts/zm/zm_abandoned_cyber_city/_acc_boss.gsc#L289)).

### 1b. Live music / ambience aliases

| Alias | What it is | Where it fires |
|---|---|---|
| `acc_main_theme` | Intro theme, once at spawn; stock ZM music suppressed (`bonuszm_musicoverride=true`). "Suspense Dark Thriller" (lnplusmusic, Pixabay #392762) | [`_acc_atmosphere.gsc`](../scripts/zm/zm_abandoned_cyber_city/_acc_atmosphere.gsc) `apply_music()`, dvar `acc_music_on` (default 1) |
| `acc_amb_city_bed` | Rainy cyber-city LOOP — **alias LIVE but gated OFF** (`acc_amb_on` default 0); author/turn on for mood | `_acc_atmosphere.gsc` `apply_ambient_bed()` |
| `acc_brutus_music` | Boss battle LOOP. "The Final Boss Battle" (alperomeresin, Pixabay #158700). Name is historical — Brutus itself is music-less | `_acc_boss.gsc::boss_music()` (Phantom), dvar `acc_boss_music_on` |
| `acc_paradise_calm` | PHASE-1 victory-fakeout fanfare (one-shot) | [`_acc_paradise.gsc:249`](../scripts/zm/zm_abandoned_cyber_city/_acc_paradise.gsc#L249) |
| `acc_paradise_omen` | Pre-onslaught omen sting (`PlayLocalSound` per player) | [`_acc_paradise.gsc:260`](../scripts/zm/zm_abandoned_cyber_city/_acc_paradise.gsc#L260) |
| `acc_paradise_music` | The "115" battle anthem at max volume (overrides + stops boss music) | [`_acc_paradise.gsc:270`](../scripts/zm/zm_abandoned_cyber_city/_acc_paradise.gsc#L270) |
| `acc_ee_song` / `_2` / `_3` | Jukebox songs (random pick; the old CENTER/LEFT/RIGHT bears) | [`_acc_jukebox.gsc:63-65`](../scripts/zm/zm_abandoned_cyber_city/_acc_jukebox.gsc#L63) |
| `mus_roundstart1_intro` / `mus_roundend1_intro` | Kino/WaW round-change stingers (WetEgg pack, aliases only). Layered on their own emitter — theme keeps playing under | `_acc_music::round_stinger_loop` hooks stock `start_of_round` / `end_of_round` |
| `mus_gameover_intro` | Game-over song; routes through the channel (stops the theme) | `_acc_music::gameover_song_watcher` on `end_game` |
| `mus_dogstart1_intro` / `mus_dogend1_intro` | In the CSV but **unhooked** — this map has no dog rounds | — |

### 1c. Live SFX aliases

| Alias | What it is | Where it fires |
|---|---|---|
| `acc_shard_pickup` → `diamond_found.wav` | Data-Shard chime — **fixes 5 call-sites** (shard grab, cache extract, Neural Expansion buy, Reactor reward, Exo tier) | `_acc_data_shards.gsc`, `_acc_perks.gsc`, `_acc_reactor.gsc`, `_acc_exo.gsc` |
| `acc_decon_alarm` → `police_box_siren.wav` (2D) | Decontamination klaxon | [`_acc_decontamination.gsc`](../scripts/zm/zm_abandoned_cyber_city/_acc_decontamination.gsc) |
| `acc_bottle_pickup` / `evt_bottle_dispense` → `glass_cling.wav` | Mega bottle acquired / dispensed at machine | [`_acc_mega_bottles.gsc`](../scripts/zm/zm_abandoned_cyber_city/_acc_mega_bottles.gsc) |
| `evt_perk_deny` / `zmb_perks_packa_deny` → `deny.wav` | Perk-slot-cap / PaP deny buzz (stock-named overrides) | `_acc_perk_info.gsc`, `_acc_pap_levels.gsc` |
| `zmb_perks_packa_upgrade` → `pap_plasma.wav`, `zmb_perks_packa_ready` → `shard_pickup.wav` | PaP cook + ready (stock-named overrides) | `_acc_pap_levels.gsc` |
| `zmb_spawn_powerup`, `zmb_powerup_grabbed` (stock-named) | Powerup drop ding + grab whoosh — **lights up EVERY drop source** (Max Ammo / Nuke / Altar boon / Emergency Drop / Reactor / elite drops all route through stock `specific_powerup_drop`) | stock `_zm_powerups.gsc` |
| `evt_nuke_flash` (stock-named) | Nuke screen-clear whoomp; also PhD dive nova | stock nuke, `_acc_perk_phd_flopper.gsc` |
| `acc_overclock_zap` | Overclock tier-up zap (3D) | [`_acc_overclocks.gsc:299`](../scripts/zm/zm_abandoned_cyber_city/_acc_overclocks.gsc#L299) |
| `acc_glitch_warp` → `warp.wav` (3D) | Glitch Stalker blink + Phantom reveal | `_acc_boss_glitch.gsc`, `_acc_boss_phantom.gsc` |
| `acc_phantom_zap` → `electric_zap.wav` (3D) | Avogadro-style on-hit zap sting (elites) + Electric Cherry | [`_acc_elites.gsc:647,679,750`](../scripts/zm/zm_abandoned_cyber_city/_acc_elites.gsc#L647), `_acc_perk_electric_cherry.gsc:248` |
| `acc_battery_zap` → `battery_zap.wav` (3D) | Volt-Battery elite surge SFX | [`_acc_elites.gsc:817`](../scripts/zm/zm_abandoned_cyber_city/_acc_elites.gsc#L817) |
| `acc_item_implant` | Implant Bench install stinger | [`_acc_boss_items.gsc:1716`](../scripts/zm/zm_abandoned_cyber_city/_acc_boss_items.gsc#L1716) |
| `acc_soul_steal` (3D) | Soul banks toward a descent gate (abyss soul boxes) | `_acc_abyss_doors.gsc::on_zombie_death_souls` |
| `acc_headshot_ding` (2D) | Headshot-KILL hitmarker ding | [`_acc_damage.gsc:546`](../scripts/zm/zm_abandoned_cyber_city/_acc_damage.gsc#L546) |

### 1d. Live perk jingles — [`_acc_mega_bottles.gsc::acc_perk_jingle_alias`](../scripts/zm/zm_abandoned_cyber_city/_acc_mega_bottles.gsc#L1059)

Every perk purchase plays its own jingle **on the vending machine (3D)** the instant
points are deducted — `perk_purchase_jingle_watch()` hooks the stock `"perk_purchased"`
notify. A **Mega** upgrade replays the perk's full jingle **loop** (`acc_jingle_<perk>_loop`)
at the machine. (The old `acc_mega_drink` heartbeat sting was **removed** 2026-06-24.)

Sting rows: `acc_jingle_{jugg, speed, doubletap, stamin, mulekick, revive, deadshot,
widows, phd, cherry}` + a matching `_loop` variant for each. Specialty map (VERIFIED(acc)
vs `_acc_perk_lights::perk_color_index`): PhD Flopper = `specialty_electriccherry` →
`acc_jingle_phd`; Electric Cherry = `specialty_combat_efficiency` → `acc_jingle_cherry`
(our own "Elemental Pop" sting). Add a row when a new perk is added.

### 1e. Packs (registered in the `.szc`, working)

`nsz_brutus.csv` (Brutus boss), `mechz_spiki.csv` (Panzer), `acc_skye_box_weapons.csv`
+ `acc_apex_weapons.csv` + `_owens_weapons.csv` + `t5_thundergun_sounds.csv` (box guns),
`elemental_bow_sounds.csv` (bows), `zm_ai_zod_companion.csv` / `zm_ai_apothicon_fury.csv`
(companion + Fury elite). **Game-rip packs are gitignored and NOT publish-cleared** (§4).
Stock starter `user_aliases.csv` + `ambient_mod` (AMBIENT `mpl_mod`) resolve from the
tools install — keep them.

---

## 2. The atmosphere target — what it should *sound* like

Fiction ([docs/20 §1](20_atmosphere_and_materials.md), [docs/00](00_overview.md)):
a **dead high-tech city** — perpetual rainy neon night, dead/flickering signage,
smog, wet reflective ground, decay over chrome; low-key noir à la Shadows of Evil /
Blade Runner 2049 / Cyberpunk 2077 derelict districts. The neon palette maps to
audio: **cyan** = live tech (hums, beeps), **magenta** = dead nightlife (distant
muffled music, silence), **amber** = dying power (electrical buzz, flicker crackle).

Target soundscape, by priority:

1. **Gameplay reads (highest value — legibility, not decoration).** Elites should be
   **audibly distinguishable offscreen in ~1 s** ([docs/08](08_enemies.md)); today the
   elite *zap* abilities emit `acc_phantom_zap` / `acc_battery_zap`, but per-elite
   *spawn* telegraphs are still unbuilt (§6.5). Bosses want a spawn boot-up surge and,
   for the Phantom, the looping battle track (LIVE).
2. **Event / UI cues.** Decon klaxon (LIVE); still-silent: Cyberware confirm/deny,
   kiosk/terminal clicks, insufficient-funds error, Hack/Reactor/Lockdown stingers.
3. **Ambient bed (per zone).** Rain/wind hiss, distant city drone, electrical buzz,
   drips. Global bed alias exists (`acc_amb_city_bed`, gated OFF). Reverb wants
   wet/cavernous undercity vs flatter plaza (§5, needs a full BSP build).
4. **Music (conditional).** Round-transition stingers (LIVE) + theme/boss/Paradise/
   jukebox tracks (LIVE).

---

## 3. Asset sourcing & licensing (the gate)

A BO3 `.ff` stores **raw, trivially-extractable audio**, so the only
unambiguously-shippable categories are **stock / self-authored / CC0**
([CLAUDE.md](../CLAUDE.md), mirrors [docs/20](20_atmosphere_and_materials.md)).

### 3a. icegrenade.co.uk — NOT for a public ship (verified)

`icegrenade.co.uk/assets/` is IceGrenade/ZGC's **"Asset Finder" — a link *index*, not
a host.** Its ToS **expressly prohibits redistribution**; ~95% of its audio is **ripped
("ported")** from Activision/Treyarch games or *other* games (Battlefield 1, Jurassic
Park) — credited names are porters, not rights-holders. Bundling these in a public
Workshop `.ff` violates the Steam Subscriber Agreement (§6.D) and our CC0-only rule,
and there are **zero** ambience/environmental-loop packs on it anyway.

**Verdict: local playtest ONLY; never in the published map.** Same class as the
existing `_NSZ`/Skye/Apex/mechz packs already flagged IP-review-pending. Treyarch-origin
ports are the tolerated grey area the scene runs on *in-engine*; third-party-game audio
(BF1/Jurassic Park) is unambiguously infringing.

### 3b. CC0 packs to use instead (verified genuinely CC0 — bundle-safe)

| Pack | Covers | Link |
|---|---|---|
| **Kenney — Sci-fi / Digital / UI Audio** | UI clicks, shard/perk pickups, robotic/EMP blips | `kenney.nl/assets/sci-fi-sounds` (+`/digital-audio`, `/ui-audio`) |
| **Tallbeard — Free Music Loop Bundle (Abstraction)** | round/EE music beds (dark/electronic) | `tallbeard.itch.io/music-loop-bundle` |
| **OpenGameArt — Joth "Ambience Pack 1: Sci-Fi Horror"** | abandoned-facility room tones / ambient bed | `opengameart.org/content/ambience-pack-1-sci-fi-horror` |
| **OpenGameArt — Joth "Cyberpunk Moonlight Sonata"** | signature theme / PaP-room track | `opengameart.org/content/cyberpunk-moonlight-sonata` |
| **ObsydianX — Interface SFX Pack 1** | kiosk/menu UI set (confirm/back/cursor/error) | `obsydianx.itch.io/interface-sfx-pack-1` |
| **Kronbits — 200 Free SFX** | alarms, lasers, electric (boss/EMP/decon) | `kronbits.itch.io/freesfx` |
| **Freesound — CC0 filter ONLY** | bespoke boss drones, sirens, teleport whoosh, machinery | `freesound.org` → license filter = *Creative Commons 0* |

**Do NOT use as-listed (license traps caught in verification):**
- **ROT: Horror Audio Bundle** is actually **paid** (~€9.97) + an unread license PDF. Dropped.
- **OGA "CC0 Sound Effects" (OwlishMedia)** is a **mixed-license collection** — at least
  one sub-item ships a no-resale `License.txt` that is NOT CC0. Prefer rubberduck's
  single "100 CC0 SFX" submissions, vetted per item.
- **Pixabay / Sonniss / Patrick de Arteaga (CC-BY)** prohibit standalone redistribution
  or require attribution → grey-area inside a `.ff`. Prototype only. *(Note: the shipped
  music tracks in §1b are Pixabay-sourced and flagged for the pre-Public IP review.)*

**Golden rule:** the binding license is the storefront tag **AND** any `License.txt`/PDF
inside the downloaded zip. **Log every source — even CC0 — in [CREDITS.md](../CREDITS.md)
before going Public.**

---

## 4. BO3 sound pipeline (how to add a cue)

Four authored layers feed **one** build step. Verified against local stock scripts,
shipped community usermaps, and the live tools install.

1. **WAV spec: 48000 Hz, 16-bit PCM (Microsoft signed).** Wrong rate/depth is the #1
   silent-failure cause — a non-48k WAV is a hard linker error (`ERROR: <wav> is not 48k
   sample rate`; the `.ff` still packs but the sound won't load). No ffmpeg on the box →
   resample dependency-free with the Node upsamplers (`tools/resample48k.js`,
   `tools/convert_wav_48k_stereo.ps1`). **2D vs 3D is the alias `Pan` column, not channel
   count** — mono and stereo both accepted.
2. **Place the WAV** under the Mod Tools `sound_assets/<folder>/` (e.g. `acc/fx/`,
   `acc/music/`, `acc/amb/`, `acc/fx/jingles/`). The CSV `FileSpec` is **relative to
   `sound_assets/`** and uses backslashes (`acc\fx\<file>.wav`).
3. **Alias row** in a `sound/aliases/*.csv` — copy the 102-column header already in
   `acc_audio.csv`. Load-bearing columns: `Name` (the GSC string), `FileSpec`,
   `Template=UIN_MOD` (fills ~90 blank cells), `Bus=BUS_FX`/`BUS_MUSIC`, `Pan=2d`
   (headlocked/UI/music) or `3d` (positional), `Looping`, `DistMin/DistMaxDry/DistMaxWet`
   (3D falloff). For music also `Storage=STREAMED`, `IsMusic`/`BUS_MUSIC`, `Pan=2d`,
   `DuckGroup=snp_never_duck`.
4. **Register the CSV** as an `ALIAS` Source in the `.szc` (`acc_audio` + `acc_round_sounds`
   + every pack are already registered). The `ambient_mod` AMBIENT block stays as-is.
5. **Zone manifest** already has `sound,zm_abandoned_cyber_city` — leave it; you never
   list CSVs/WAVs individually.
6. **Point the code at it** — either a new `PlaySound("acc_x")` /
   `PlaySoundAtPosition` / `PlayLoopSound` at the site, or (for a stock-driven flow) an
   `acc_audio.csv` row **named exactly the stock alias** the prefab already calls (§0).

**Playback idioms (server `.gsc`):**
- One-shot positional: `ent PlaySound("alias")` / `PlaySoundAtPosition("alias", origin)`.
- Player-local (dog-round-start idiom): `player PlayLocalSound("alias")`.
- 2D to all players: `zm_utility::play_sound_2D("alias")` (no stop handle — do NOT use
  for a song; use the music channel, §1a).
- Looping emitter: `LOOPING` alias + `ent PlayLoopSound("alias")`; stop with `StopLoopSound()`.
- **Songs: use `acc_music::play(alias, looping)`** — never spawn your own song emitter.

**Reverb is BSP-driven, NOT scriptable server-side.** Place Radiant `trigger_multiple`
volumes (`targetname ambient_room`, `script_ambientroom <stock room>`,
`script_ambientpriority`, **CLIENTSIDE_TRIGGER** checked) → the engine fires
`CodeCallback_SoundSetAmbientState` → `forceambientroom` on the client. Room names
resolve through stock `ambient_mod.csv` to presets in `share/raw/sound/reverb/common_reverb.csv`
(e.g. `global_urban_outdoor`, `factory_largeroom`). A server `_acc_*.gsc` **cannot** set
reverb (separate VM). Per-zone reverb therefore forces a full `cod2map64`(cwd=`bin`)+LED+linker
build (success marker: `<map>.ambientgeometry.json` appears).

---

## 5. Per-event map — what's wired, what's still silent

Folded from the 187-event code audit. **Line numbers are audit-era (2026-06/07) and may
have drifted** — grep the function name if a line looks off. State reconciled against
the current `acc_audio.csv` / `_acc_music.gsc` alias inventory (§1).

**State legend:**
`LIVE` = alias defined + a call fires it (plays today) · `SILENT(no-alias)` = a call
fires an alias not yet in any CSV → add the WAV+row · `SILENT(stock)` = code (ours or a
stock prefab) calls an undefined stock alias → add a row named exactly that alias, or
repoint · `NONE` = no `PlaySound` call exists yet → add call + alias ·
`RETIRED` = feature removed, ignore.

### 5.1 Progression & Buys

| Event | Where it fires | State | Notes / alias |
|---|---|---|---|
| Mega upgrade APPLIED (drink + jingle loop) | `_acc_mega_bottles.gsc:~428` | **LIVE** | plays `acc_jingle_<perk>_loop` on the machine; old `acc_mega_drink` removed |
| Normal perk BUY jingle | `perk_purchase_jingle_watch` (stock `perk_purchased`) | **LIVE** | `acc_jingle_<perk>` on the vending machine, every perk |
| Neural Expansion +1 slot BUY | `_acc_perks.gsc:204` | **LIVE** | `acc_shard_pickup` |
| Exo Suit body TIER UP | `_acc_exo.gsc:138` | **LIVE** | `acc_shard_pickup` |
| Overclock weapon TIER UP (zap) | `_acc_overclocks.gsc:299` | **LIVE** | `acc_overclock_zap` |
| PaP first pack / tier-up (cook + ready) | `_acc_pap_levels.gsc:292,302,337,367` | **LIVE** | `zmb_perks_packa_upgrade` + `zmb_perks_packa_ready` |
| PaP DENY / slot-cap perk DENY | `_acc_pap_levels.gsc:279,332`; `_acc_perk_info.gsc:143` | **LIVE** | `zmb_perks_packa_deny` / `evt_perk_deny` |
| PhD slide/down NOVA explosion | `_acc_perk_phd_flopper.gsc:262` | **LIVE** | `evt_nuke_flash` |
| Mega bottle DISPENSE at machine | `_acc_mega_bottles.gsc:441` | **LIVE** | `evt_bottle_dispense` → `glass_cling.wav` |
| Mega upgrade DENY (already mega'd / no bottle) | `_acc_mega_bottles.gsc:471,477` | NONE | wire `zmb_perks_packa_deny` (now defined) |
| Mega re-drink anim gulp | `_acc_mega_bottles.gsc:260` | SILENT(stock) | `zmb_perks_drink` — not authored |
| Empty Mega Bottle GRANTED (boss kill) | `_acc_mega_bottles.gsc:177` | NONE | glassy reward clink |
| Neural Expansion DENY | `_acc_perks.gsc:190,198` | NONE | wire `zmb_perks_packa_deny` |
| Overclock DENY (4 paths) | `_acc_overclocks.gsc:255,261,280,289` | NONE | wire `zmb_perks_packa_deny` |
| PaP re-pack on maxed gun | `_acc_pap_levels.gsc:323-326` | NONE | short deny |
| Exo Suit DENY | `_acc_exo.gsc:123,132` | NONE | wire `zmb_perks_packa_deny` |
| Widow's Wine web restock | `_acc_mega_bottles.gsc:115` | NONE | optional tick |
| Quick Revive / Savior revive complete | `_acc_perks.gsc:314` (stock-driven) | SILENT(stock) | `zmb_perks_revive_jingle` (`acc_jingle_revive` is the *buy* jingle, not this) |
| Cyberware node buy / respec / abilities | `_acc_cyberware.gsc:279,324,445,679,759,840` | NONE | **tree disabled** — defer |

### 5.2 Pickups, Economy & Powerups

| Event | Where it fires | State | Notes / alias |
|---|---|---|---|
| **Data Shard PICKUP** (world drop) | `_acc_data_shards.gsc:336` | **LIVE** | `acc_shard_pickup` (the currency finally chimes) |
| Data Cache EXTRACTED | `_acc_data_shards.gsc:268` | **LIVE** | `acc_shard_pickup` |
| **Powerup drop + grab (ALL sources)** | stock `_zm_powerups.gsc` via `specific_powerup_drop` | **LIVE** | `zmb_spawn_powerup` + `zmb_powerup_grabbed` — one pair covers Max Ammo / Insta-Kill / Nuke / Double Points / Fire Sale / Carpenter / Free Perk **and** every Altar/Emergency/Reactor/elite drop |
| Nuke screen-clear whoomp | stock `_zm_powerup_nuke.gsc` | **LIVE** | `evt_nuke_flash` |
| Announcer VO (Max Ammo!/Nuke!/…) | stock powerups | SILENT(stock) | `vox_zmba_powerup_*` not authored |
| Powerup IDLE beacon loop | `_zm_powerups.gsc:833` | SILENT(stock) | `zmb_spawn_powerup_loop` |
| Reactor STABILIZED success | `_acc_reactor.gsc:189-191` | **LIVE** | `acc_shard_pickup` (+ wants a fanfare) |
| Implant Bench item ENABLED | `_acc_boss_items.gsc:1716` | **LIVE** | `acc_item_implant` |
| Glitch Altar BOON (powerup drop) | `_acc_glitch_altar.gsc:190-215` | **LIVE(drop/grab)** | routes through stock drop → dings; the *win-tier* chimes (jackpot/mega/curse) are NONE |
| Data Cache DENY / re-arm; Shards +N HUD tick | `_acc_data_shards.gsc:141,263,283` | NONE | soft buzz / recharge / income tick |
| Glitch Altar spin / win-tier / curse / deny cues | `_acc_glitch_altar.gsc:138-228` | NONE | slot whir, jackpot fanfare, curse alarms |
| Reactor armed / per-wave / failed / deny | `_acc_reactor.gsc:120-180` | NONE | klaxon, surge whoosh, meltdown whine |
| Emergency Drop purchased / outcome / deny | `_acc_emergency_drop.gsc:79-142` | mostly NONE | powerup-routed rewards ride the LIVE drop ding |
| Boss item world-drop / grabbed / dupe→shards | `_acc_boss_items.gsc:313,394,370` | NONE | glint / whoosh / shard chime |
| Gas Tank / Li'l Arnie / Cymbal / Phase Serum / Repair / Rocket Shield | `_acc_boss_items.gsc:724-1109` | NONE | per-item activation cues |

### 5.3 Bosses

**Roster** (all real, current): Brutus (NSZ pack), Glitch Stalker, Phantom, Avogadro,
Panzer (mechz), Rogue/Civil Protector. Mini-boss first appears r10; full boss rounds
every 9 from r9 (r9=1, r18=2, …); types from a no-duplicate shuffled deck.
avogadro/civil_protector/panzer are threaded from the **entry script**
([`zm_abandoned_cyber_city.gsc`](../scripts/zm/zm_abandoned_cyber_city.gsc)).

| Event | Where it fires | State | Notes / alias |
|---|---|---|---|
| Boss MUSIC loop (Phantom = "real boss") | `_acc_boss.gsc::boss_music()` :315 | **LIVE** | `acc_brutus_music`; hard-stop no fade (music channel) |
| Glitch Stalker teleport-blink | `_acc_boss_glitch.gsc:442` | **LIVE** | `acc_glitch_warp` (3D) |
| Phantom materialize reveal | `_acc_boss_phantom.gsc:368` | **LIVE** | reuses `acc_glitch_warp` |
| Boss headshot KILL ding | `_acc_damage.gsc:546` | **LIVE** | `acc_headshot_ding` |
| Brutus full SFX suite (spawn/step/swing/helmet/death) | `_NSZ/nsz_brutus.gsc` | **LIVE (NSZ pack)** | — |
| Panzer SFX | `mechz_spiki.csv` | **LIVE (pack)** | — |
| Boss kill REWARD sting | `_acc_boss.gsc:302-329` | NONE | triumphant sting |
| Generic boss SPAWN telegraph | `_acc_boss.gsc:390-498` | NONE | boot-up surge (`zmb_mechz_spawn`) |
| Boss phase transitions (power out / perks off / restore / enrage) | `_acc_boss.gsc:598-711` | NONE | `zmb_power_off` / `zmb_perks_shatter` / `zmb_power_on` |
| Boss DEATH + reward | `_acc_boss.gsc:377-550` | NONE | death explosion + victory sting |
| Glitch Stalker wave-inbound / spawn / pounce / vuln-window / death | `_acc_boss_glitch.gsc:176-719` | NONE | signature mini-boss reads (blink is LIVE) |
| Phantom inbound / arrival / death drop | `_acc_boss_phantom.gsc:170-416` | NONE | reveal reuses warp (LIVE) |
| Boss non-lethal body thunk | `_acc_damage.gsc:283` | NONE | subtle metallic |

### 5.4 Events & Traps

| Event | Where it fires | State | Notes / alias |
|---|---|---|---|
| **Decon WARNING / start klaxon** | `_acc_decontamination.gsc:245,253` | **LIVE** | `acc_decon_alarm` → `police_box_siren.wav` |
| Lockdown confined glitch spawns | `_acc_lockdown_challenge.gsc:225-254` | **LIVE** | `acc_glitch_warp` per spawn |
| Decon T-10s/T-5s beeps, zone-sealed slam, straggler gas | `_acc_decontamination.gsc:256-557` | NONE | countdown beeps, door slam, gas zap |
| Hack event (start / stages / success / fail / penalty / deny) | `_acc_events_hack.gsc:107-419` | NONE | terminal boot-up, access granted/denied, horde surge |
| DEFCON / Lockdown seals (armed / engaged / cleared / failed) | `_acc_lockdown.gsc`, `_acc_lockdown_challenge.gsc` | NONE | red-alert bed, blast-door slam, victory/failure |
| Bus Trench fall tax / danger / surge / descend / drip | `_acc_bus_trench.gsc:222-895` | NONE | land thud, dread drone, eruption roar, bass swell |
| **Vault Overload side-event (all rows)** | `_acc_events_overload.gsc` | **RETIRED** | commented out at `_acc_main.gsc:199` (2026-07-07); ignore — the module file still exists but never inits |

### 5.5 Combat & Enemies

> **Elite taxonomy note:** the elite system evolved past the old Shielded/Teleporter/EMP
> trio — the zap abilities now emit `acc_phantom_zap` (Avogadro-style) / `acc_battery_zap`
> (Volt Battery). Treat the pre-spawn/telegraph rows below as still-unbuilt reads; grep
> `_acc_elites.gsc` before wiring since function names moved.

| Event | Where it fires | State | Notes / alias |
|---|---|---|---|
| Headshot KILL ding | `_acc_damage.gsc:546` | **LIVE** | `acc_headshot_ding` |
| Elite on-hit zap (Avogadro-type) | `_acc_elites.gsc:647,679,750` | **LIVE** | `acc_phantom_zap` |
| Volt-Battery elite surge | `_acc_elites.gsc:817` | **LIVE** | `acc_battery_zap` |
| ACC round START / END stingers | stock `start_of_round`/`end_of_round` → `_acc_music` | **LIVE** | `mus_roundstart1_intro` / `mus_roundend1_intro` |
| Elite SPAWN telegraphs (per type) | `_acc_elites.gsc:229-277` | NONE | pre-spawn clank / phase-in / EMP hum |
| Shield frontal-absorb ricochet; shield break | `_acc_damage.gsc:504-513`; `_acc_elites.gsc:365-389` | NONE | flank cue |
| Crit proc; EMP lockout expire; T3 recursion drop | `_acc_damage.gsc:307`; `_acc_elites.gsc:353,391` | NONE | reuse zap / reboot blip |
| Weapon-ability activate / deny / ready / mode arms / whirlwind | `_acc_weapon_abilities.gsc:221-396` | NONE | ability whoosh, scope click, spin-up, AoE gust |
| Elite pressure pulse / special-round announce / last-zombie | `_acc_elites.gsc:122-154`; `_acc_main.gsc` | NONE | warning swell, klaxon, tension cue |
| Modifier / Draft / Roguelike / Express cues | `_acc_modifiers.gsc:156-244` | NONE | one-time ruleset tones |
| Adaptive-Aim refund / Kinetic-Battery charged shot | `_acc_damage.gsc:471-753` | NONE | ammo blip / charged thump |

### 5.6 World, Atmosphere & UI

| Event | Where it fires | State | Notes / alias |
|---|---|---|---|
| Map intro THEME (once) + stock music killed | `_acc_atmosphere.gsc` `apply_music()` | **LIVE** | `acc_main_theme` |
| GAME OVER song + round transitions | `_acc_music` (`end_game`, round notifies) | **LIVE** | `mus_gameover_intro` + round stingers |
| PaP cook/ready/deny; slot-cap DENY; Mega dispense; PhD nova | see §5.1 | **LIVE** | stock-named overrides |
| Data Shard pickup/spend confirm (5 sites) | shards/perks/reactor/exo | **LIVE** | `acc_shard_pickup` |
| Decon klaxon | `_acc_decontamination.gsc:253` | **LIVE** | `acc_decon_alarm` |
| Ambient city/rain bed | `_acc_atmosphere.gsc` `apply_ambient_bed()` | **LIVE but OFF** | `acc_amb_city_bed` — `set acc_amb_on 1` |
| **POWER ON — the breaker flip** | stock `_zm_power.gsc` prefab | SILENT(stock) | `zmb_switch_flip` + `zmb_power_on` — high-value gap |
| **Door BUY + open** (8 buyable + 2 underground) | `_zm_blockers.gsc` | SILENT(stock) | `zmb_buildable_purchase` + `zmb_door_slide_open` |
| **Mystery BOX full suite** | `_zm_magicbox.gsc` | SILENT(stock) | `zmb_box_open/gun_loop/ready/move/teddy_giggle` |
| **Player DOWNED → last stand** | stock `_zm_laststand.gsc` | SILENT(stock) | `zmb_laststand_down` + `zmb_heartbeat_loop` |
| **Revive start + complete** | stock `_zm_laststand.gsc` | SILENT(stock) | `zmb_revive_start` + `zmb_revive_finished` |
| **Points blip + generic purchase cha-ching** | stock `zm_score::` + buyable triggers | SILENT(stock) | `zmb_cha_ching` / `zmb_points_gain` |
| Perk machines / PaP light-up on power | `_acc_perk_lights.gsc:71` (visual only) | NONE | flicker-on buzz + jingle loops |

---

## 6. Top-priority next wires (biggest remaining silences)

Ordered by how often a player hits them × how dead the silence feels. All are
stock-driven prefab flows → fixable by adding an `acc_audio.csv` row **named exactly the
stock alias** (§0), no code edit:

1. **Mystery Box full suite** — the single most-used object, currently mimes silently
   (`zmb_box_open/gun_loop/ready/move/teddy_giggle`).
2. **Power ON breaker** — the biggest atmosphere beat (`zmb_switch_flip` + `zmb_power_on`).
3. **Door buy + open** — 10 doors, every purchase silent
   (`zmb_buildable_purchase` + `zmb_door_slide_open`).
4. **Player downed + Revive** — critical co-op UX
   (`zmb_laststand_down`/`heartbeat_loop`/`revive_start`/`revive_finished`).
5. **Points blip + generic purchase cha-ching** — the constant dopamine loop
   (`zmb_cha_ching` / `zmb_points_gain`).
6. **Announcer powerup VO** — the drop ding/grab already play (§5.2); add
   `vox_zmba_powerup_*` for Max Ammo/Insta-Kill/Nuke/Double Points/Fire Sale/Carpenter.
7. **Boss telegraphs** — generic boss spawn surge + death sting + Glitch Stalker
   wave-inbound / vuln-window (makes the signature bosses readable by ear).
8. **Event alarms** — Decon countdown beeps + seal slam, Hack success/fail, Reactor
   klaxon, Trench danger/surge, Lockdown seal.

---

## 7. Risks & gotchas (verify on the Windows box)

**Licensing (highest risk):**
- The game-rip weapon/boss packs (`acc_skye_box_weapons`, `acc_apex_weapons`,
  `nsz_brutus`, `mechz_spiki`, `_owens_weapons`, bows, companion/Fury) are **not
  publish-cleared**; the shipped music tracks are **Pixabay** (grey-area in a `.ff`).
  Do **not** flip the Workshop item Public until [CREDITS.md](../CREDITS.md) lists every
  audio source and the IP review passes. Re-check each CC0 download's in-zip `License.txt`.

**Build-tool gotchas:**
- **The `.sabs` bank is file-locked while BlackOps3 is RUNNING** → a sound-stage build
  reuses the stale bank (sync can't delete the locked `CachedBanks`), so a new/changed
  sound **does not compile until a GAME-CLOSED build**. Symptom: valid alias, no linker
  error, yet silent. Close the game, then build. *(The old "GSC-only relink reuses stale
  soundbanks" caveat is otherwise WRONG — the `.sabs`/`.alias.sz` mtime advances on a
  `-GscOnly` build; sound-only changes are `-GscOnly` + game-closed.)*
- Linker builds the **deployed** usermap copy → `tools/sync_to_modtools.ps1` first, and
  make sure the WAVs are in the tools `sound_assets/` tree.
- **A malformed `FileSpec` aborts the WHOLE sound build** (`Parse error … Illegal
  characters`) — e.g. a lost `\` → `accxheadshot_ding.wav`. Keep FileSpecs `acc\<dir>\<file>.wav`.
  One bad/missing WAV in any registered CSV can also abort it → isolate by removing the row.
- **WAVs MUST be 48 kHz / 16-bit PCM.** Resample with `tools/resample48k.js` (2× frame
  dup, mono) or `tools/convert_wav_48k_stereo.ps1` (stereo, `-TrimSeconds` to trim). For
  pristine quality re-export the source at 48k instead.
- Reverb (per-zone) requires the heavier `cod2map64`+LED+linker geometry build, not a
  linker-only pass. Any client `forceambientroom`/decon-LUI widget is `.csc`-only (needs
  L3akMod; can't call `.gsc`).

**Swapping a shipped track:** drop the new 48k WAV in at the same `FileSpec` filename
(e.g. `sound_assets/acc/music/main_theme.wav`, `brutus_music.wav`) → alias unchanged →
GAME-CLOSED build. `acc_brutus_music` is ~44 MB (STREAMED); trim if package size matters.

**To verify on Windows (TODO):**
1. Confirm which stock-named override rows actually resolve the prefab calls in-game
   (box/door/power/laststand) — some stock SFX are viewmodel-anim notetracks we can't reach.
2. Confirm stock `common_reverb.csv` `mpl_mod` room names available for per-zone reverb.

---

## 8. Decisions / cross-links

- **Owning doc:** this file (35) owns audio direction; [docs/20 §15](20_atmosphere_and_materials.md)
  carries a one-paragraph pointer here.
- **Locked:** icegrenade/ported audio = local-only; shippable audio = CC0/self-authored;
  gameplay reads outrank mood and music in value; **one song at a time** via the music channel.
- Related memory: `custom-sound-48k-and-game-lock` (48k requirement + `.sabs` game-lock),
  `jukebox-replaces-teddy-bears` (the `acc_ee_song*` aliases kept to dodge a bank rebuild).
