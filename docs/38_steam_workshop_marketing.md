# 38 — Steam Workshop marketing / store-page kit

Working source for the Workshop store page: how images actually work on Steam, the
paste-ready description (BBCode) with image slots, the shot list, and the gallery plan.
Visual companion (storyboard mockup) is generated as an Artifact from this same content.

**Goal (user, 2026-07-06):** reinvent the store page to *sell* — Abandoned Cyber City the
place, the challenge-map identity, the difficult Abyss/Trench descent, the Apex Legends guns,
the boss roster, and the insane all-boss Paradise finale. Tighter than the old copy; show
players what they're missing; exaggeration is sanctioned. Add images with clear placeholders.

---

## 1. How images work on a Steam Workshop item (READ FIRST)

A Workshop **item** page has **two separate image surfaces**. Use both — they behave differently.

### A. The gallery (preview image + screenshots) — your #1 real estate, always renders
These are image **files you attach** when you edit the item (not BBCode). The **primary preview
image** is what shows in Browse/Search and at the top of the page; the extra **screenshots** form
the thumbnail strip. They never break. **Invest here first.**
- Primary preview: **16:9**, ship at least **637×358** (bigger is fine, it downscales). Put the
  **title text** on it — it's your poster.
- Add **5–8 screenshots**: one boss, the abyss, an Apex gun, the Paradise chaos, the HUD, a co-op
  moment. Grab in-game at **1920×1080**.

### B. In-description images (`[img]` BBCode) — the inline placeholders in the copy below
Inline images inside the description text. **This is where the "placeholders" go.** The catch:

> **Steam Workshop item descriptions only render images hosted on Steam's own CDN.**
> External hosts (imgur, Discord, your own server) are frequently **blocked / shown broken**.

**How to get a Steam-CDN URL (the reliable method):**
1. Upload each image to your Steam profile as **Artwork**: Profile → **Screenshots/Artwork** →
   **Upload Artwork** (visibility Public or Unlisted). *(A screenshot you upload works too.)*
2. Open the uploaded image at **full size**, right-click it → **Copy image address**.
3. You get a URL like `https://steamuserimages-a.akamaihd.net/ugc/...`. Paste it between
   `[img]` and `[/img]`.

**Rules of thumb**
- **Width:** export in-description images **≤ 627px** wide (full-page view) / **≤ 425px** (the
  windowed subscribe modal) so they never overflow the column.
- **GIFs render** — a short looping gameplay GIF (Paradise chaos, a boss charge) beats a still.
  Keep it a few MB.
- **Always preview after saving.** A broken image = the host was blocked → re-host on Steam's CDN.
- **Clickable image → trailer:** `[url=https://youtu.be/YOURID][img]STEAM_CDN_URL[/img][/url]`
- **Fallback if `[img]` ever refuses to render** for the item: lean on the gallery + a plain
  YouTube trailer link. A gallery + trailer alone is already a strong page.

### Supported BBCode in the description
`[b] [i] [u] [strike] [h1] [h2] [h3] [url] [img] [list]/[olist]/[*] [quote] [code] [spoiler]
[hr][/hr]`. No comments and no CSS — keep it to these.

---

## 2. Paste-ready description (BBCode)

Copy this whole block into the Workshop item's description. The hero `[img]` (line 1 of the
block) already carries a real Steam-CDN URL; the remaining **six** `[img]` lines still carry
obvious placeholder URLs (`REPLACE-WITH-STEAM-CDN-URL/...`) — swap each for a real Steam-CDN
link (§1B). Any you forget will show visibly broken (a feature, not a bug — you'll notice).
Shot details for each are in §3.

```
[img]https://images.steamusercontent.com/ugc/16177977399189878707/3494AAC15198CB43E3922F68282991119D83DB05/?imw=5000&imh=5000&ima=fit&impolicy=Letterbox&imcolor=%23000000&letterbox=false[/img]

[h1]ABANDONED CYBER CITY[/h1]
[b]The neon never turned off. Neither did whatever's still down there.[/b]

This isn't a normal zombies map. It's a [b]descent[/b]. Build a character from nothing, drop
below the streets, and claw DOWN through an Abyss that gets deadlier every floor. The bottom
is real — and almost nobody reaches it.

[b]Think you can?[/b]

[hr][/hr]

[img]https://images.steamusercontent.com/ugc/10310496277133168107/8E87FAE510213BA88A64EC6E93A1854ED8C6C0DD/?imw=5000&imh=5000&ima=fit&impolicy=Letterbox&imcolor=%23000000&letterbox=false[/img]

[h1]⬢ THE CITY THAT FIGHTS BACK[/h1]
A dead neon metropolis of busted power and cyber-tech gone dark. Turn
the power on, crack the doors, and find the trench cut straight through its heart. Because the
only way forward is [b]down[/b].

[hr][/hr]

[img]https://images.steamusercontent.com/ugc/15737522797851495934/E93CCD85371B5C6B10FA366B0377EA9103EC42E7/?imw=5000&imh=5000&ima=fit&impolicy=Letterbox&imcolor=%23000000&letterbox=false[/img]

[h1]⬇ THE DESCENT — FIVE FLOORS OF ABYSS[/h1]
Below the streets the map drops into a vertical Abyss. [b]Five layers. Each one deeper is
faster, tankier, and hits harder than the last.[/b] Bank souls to crack the next gate open.
The payoff for going deep? The strongest wall-guns in the game are chalked on the bottom
floors — if you live long enough to buy them.

[b]Risk it, or stay shallow and stay weak.[/b]

[hr][/hr]

[img]https://images.steamusercontent.com/ugc/12597091942071439659/48528BF20F3CBBB241083367CDF8B90CB21FF38B/?imw=5000&imh=5000&ima=fit&impolicy=Letterbox&imcolor=%23000000&letterbox=false[/img]

[h1]⚙ BUILD A MONSTER[/h1]
Bank [b]Data Shards[/b] down in the trench and spend them on power that sticks: bolt an
[b]Exo Suit[/b] onto your body, [b]Overclock[/b] your favorite gun tier by tier, unlock extra
perk slots, and gamble at the Glitch Altar. Rip [b]cyber-implants[/b] out of dead bosses —
an 11-item loot pool, 3 implant slots, endless build combos. Then chase [b]Mega perks[/b] —
boss-tier upgrades that turn survival tools into win conditions. Triple-tier Pack-a-Punch
on top of it all.

[hr][/hr]

[img]https://images.steamusercontent.com/ugc/14813031108365527832/3F2066C0F4400C28E2FB124F7C677C273CDCBC78/?imw=2048&imh=1152&ima=fit&impolicy=Letterbox&imcolor=%23000000&letterbox=true[/img]

[h1]🔫 THE ARSENAL — SIX COD GAMES… AND APEX LEGENDS[/h1]
Over 30 box weapons pulled from six Call of Duty games and a squad ripped straight out of
[b]Apex Legends[/b] — most Pack-a-Punchable and Overclock-ready, topped with FIVE wonder weapons:
[list]
[*][b]From Apex Legends:[/b] Prowler · Alternator · Peacekeeper · Triple Take · Havoc Beam Rifle
[*][b]Five wonder weapons:[/b] Thundergun · Blast-O-Matic · Fire Bow · God of War's Leviathan Axe · Winter's Howl freeze gun
[*][b]Melee & utility:[/b] Action Figure swing · Ballistic Knife (Krauss teammate revive)
[*][b]Heavy hitters:[/b] AK-47 · M60 · PPSh-41 · HAMR · MORS railgun · Mahem launcher — and a dozen more
[/list]

[hr][/hr]

[img]https://images.steamusercontent.com/ugc/14596091217832613525/494DAEB94307F07A7D20E0F8E2280E37DE16B0D5/?imw=5000&imh=5000&ima=fit&impolicy=Letterbox&imcolor=%23000000&letterbox=false[/img]

[h1]☠ FIVE BOSSES. NONE OF THEM PLAY FAIR.[/h1]
Boss rounds escalate in number and never roll the same twice:
[list]
[*][b]The Panzer[/b] — a sprinting mech with a flamethrower and an electro-claw.
[*][b]The Trench Warden[/b] — a wall of armor that owns the trench.
[*][b]The Phantom[/b] — a holographic cloaker that hunts you across the whole map.
[*][b]The Rogue Protector[/b] — the city's own security, turned killer.
[*][b]Avogadro[/b] — a living storm that switches your perks OFF mid-fight.
[/list]
Every boss you drop leaves loot behind. Take it. You'll need it.

And between boss rounds? [b]The Glitch Stalker[/b] — a blinking, teleporting mini-boss that
hunts you every other round, in ever-growing numbers. You're never safe for long.

[hr][/hr]

[img]https://images.steamusercontent.com/ugc/16786685705177830828/43E1767E508C71DBCFF3512CD7CB59F6C54F86A6/?imw=5000&imh=5000&ima=fit&impolicy=Letterbox&imcolor=%23000000&letterbox=false[/img]

[h1]🎖 PLAY AS THE ORIGINAL CREW[/h1]
Dempsey. Nikolai. Takeo. Richtofen. The classic crew is back — dropped into a neon city that
has never heard of them, with matching character portraits on a fully custom HUD.

[h1]🌆 PARADISE — THE FINALE AT THE BOTTOM[/h1]
Reach the bottom of the Trench and a door opens to [b]Paradise[/b]. A victory jingle. Clear air.
Calm.

It's a trap. Paradise is the map's final exam: a timed onslaught that throws [b]the entire
boss roster at you at once[/b] in one sealed arena. Survive it and you don't just get a high
round — [b]you WIN the match.[/b] Yes, this zombies map has an actual ending. Almost nobody
has seen it.

[img]REPLACE-WITH-STEAM-CDN-URL/shot-07-paradise-finale[/img]

[hr][/hr]

[h1]DROP IN[/h1]
[list]
[*]Solo or 4-player co-op, tuned for a ceiling worth grinding toward
[*]Fresh every round: a rotating 4-of-10 perk lineup, a weighted mystery box, and a no-repeat boss deck
[*]Deep progression: Data Shards, Overclocks, triple-tier Pack-a-Punch, Mega perks, boss implants
[*]Built for teams: hand guns to teammates at the Armory, pool resources in the Exchange vault
[*]A true endgame with a real win condition — and a jukebox
[/list]

[b]How deep can you get?[/b] Subscribe, drop in, and find your floor.

[i]Note: this map updates often. If you don't see the latest changes, unsubscribe and
resubscribe to force an update.[/i]
```

---

## 3. Shot list — the seven in-description images + the gallery

Stage clean shots in the map's built-in **dev/test mode**: hardcode `level.acc_dev = true;` +
`level.acc_god = true;` in `acc_resolve_dev_flags()` and rebuild (the 2026-07-15 test workflow —
launch flags are not used; docs/22), then launch `PLAY_NORMAL.bat`. Dev gives the open economy and
test spawns to frame the bosses and Paradise; god (demigod) keeps you alive while framing. Flip
the Bus Station power switch yourself. Grab at **1920×1080**, then downscale in-description
images to **≤627px** wide. (reconciled to the single-launcher workflow 2026-07-15)

| Slot | Section | What to shoot | Framing / tips |
|---|---|---|---|
| **SHOT 1** | Hero (top) | The city at night — neon skyline, fog, signage | Wide vista from a rooftop/plaza. This can reuse the preview art with title text. |
| **SHOT 2** | The City | A neon street/plaza with a few zombies | Ground level, neon-lit, a couple of zombies for menace. |
| **SHOT 3** | The Descent | Looking **down** the abyss stairwell into black, or a deep floor | Emphasize verticality + darkness. Stand at a well edge and look straight down. |
| **SHOT 4** | Build a Monster | HUD close-up: Data Shards, EXO SUIT N/10, Overclock vN, perk row | Get kitted in dev mode; frame the HUD corner so the systems read. |
| **SHOT 5** | The Arsenal | An **Apex gun in hand** + the wall, or a glowing PaP'd gun | Show an Apex weapon prominently — it's the differentiator. *(See note below.)* |
| **SHOT 6** | The Bosses | The scariest boss mid-fight (Avogadro zapping / Trench Warden charging) | Action shot with the boss health bar visible. |
| **SHOT 7** | Paradise | The open-air night plaza during the all-boss onslaught — the money shot | The most chaotic frame you can get: multiple bosses + horde in the sealed arena. |

**Gallery (attach as files, §1A):** preview image (SHOT 1 with title text) + 5–8 of the above at
full 1920×1080. Order them boss → abyss → Apex gun → Paradise → HUD so the thumbnail strip sells
at a glance.

> **SHOT 5 note:** the Apex guns are imported — the weapon table (`zm_levelcommon_weapons.csv`)
> carries `apex_peacekeeper`, `apex_prowler`, `apex_alternator`, and `apex_beam_rifle`
> (the G7 Scout `apex_g2a4` was retired 2026-07-11, replaced by the CW M16). SHOT 5 should be a real Apex-gun-in-hand screenshot —
> it's the differentiator, so frame the weapon prominently.

---

## 4. What changed vs the old description (rationale)

- **Cut the length ~40%.** Old copy explained the systems (currencies, PaP tiers, box odds). New
  copy *sells* them — one punchy promise per section, numbers moved to the in-game guide (docs/36).
- **Reordered around the hooks the user named:** City → Descent/Abyss → Progression → Apex arsenal
  → Six bosses → Paradise finale → CTA.
- **Apex pulled into its own headline** ("SIX COD GAMES… AND APEX LEGENDS") and listed first — it's
  the differentiator, so it leads.
- **Named the bosses** with a one-line threat each (old copy said "and more"); the finale now
  explicitly pays off "every boss at once." (The live roster is FIVE bosses — Trench Warden,
  Phantom, Rogue Protector, Avogadro, Panzer; the every-9 boss rounds deal from a no-duplicate
  deck of Phantom/Protector/Avogadro/Panzer. The Glitch Stalker is a frequent every-2nd-round
  MINI-boss, not a roster boss — marketed as the between-rounds threat, never in the boss count.)
- **Paradise reframed as the win condition + the brag** ("This map has a top") with the calm→lie
  fakeout, which is the map's best marketing beat.
- **Seven image slots added inline**, plus a gallery/preview plan — the old page was text-only.
- **2026-07-11 refresh (user: "simple, up to date, exaggerations that sell"):** arsenal list
  reconciled to the live weapon table (G7 Scout out, CW M16 + HAMR in; wonders led by Fire Bow +
  Leviathan Axe); boss section corrected to the FIVE true roster
  bosses (Panzer / Trench Warden / Phantom / Rogue Protector / Avogadro — user 2026-07-11: "Glitch
  Stalker is not a boss") with punchier one-liners + a "every boss drops loot" hook, and the Glitch
  Stalker recast as the between-rounds mini-boss threat; NEW section "Play as the original crew"
  (Ultimis body swap + HUD portraits, a top-tier zombies-fan draw); "Build a Monster" now sells the
  11-item boss-implant pool (3 slots); Paradise rewritten to its real design — calm fakeout → timed
  all-boss onslaught → an actual WIN condition; Drop In bullets add the Armory gun-sharing /
  Exchange vault co-op hook and the jukebox.
