# 56 — Super Simple Guide: Put the Map Online & Play With Friends

The easy, no-jargon version. (The detailed version is
[55_release_runbook.md](55_release_runbook.md) — you don't need it.)

---

## First, the one thing that clears up the confusion

- A **"script"** is just a command that builds the map. **You do NOT run scripts.
  Claude runs all of them for you.**
- **Your only two jobs are: (1) click _Upload_ in one program, and (2) play.**
- There is **no website to go to.** The upload happens inside a program called the
  **Launcher** (it comes with the Black Ops 3 Mod Tools).

---

## STEP 1 — Ask Claude to build it

Just type to Claude:  **"Build the release."**

Claude does all the script stuff and tells you when the map file is ready (~15 min).
You don't type any commands. (It may already be built — Claude will tell you.)

---

## STEP 2 — Open the Launcher (the upload program)

1. Open **Steam**.
2. Click **Library** (top of Steam).
3. In the little search box, type **mod tools**.
4. Click **"Call of Duty: Black Ops III - Mod Tools"**, then click the blue **PLAY** button.
5. A small window opens with several buttons. Click **Launcher**.

> ⚠️ Before you do anything, **close the actual game** (Black Ops 3) if it's open.

---

## STEP 3 — Upload the map  (this is "where you go to upload")

Inside the Launcher window:

1. Find the map list and **click `zm_abandoned_cyber_city`** so it's highlighted.
2. Find **Publish**. It's one of these (depends on your Launcher version):
   - a button that says **Publish**, **or**
   - the top menu **File → Publish Mod/Map**, **or**
   - a tab named **Publish** / **Workshop**.
   Click it.
3. A form pops up. Most of it is already filled in. Just check these:
   - **Title:** `Abandoned Cyber City`
   - **Tags:** `Map`, `Zombies`
   - **Thumbnail / preview image:** if it asks for one, pick the file
     `zone\previewimage.png` from your project folder.
   - **Visibility:** choose **Friends Only**.  ← important. Do **NOT** pick *Public* yet.
4. Click **Upload** (or **Publish**). Wait about a minute.
5. When it finishes it shows a **link (web address)**. **Copy that link and keep it.**

---

## STEP 4 — Tell Claude you uploaded it

Type to Claude:  **"I published it."**

Claude runs one tiny save-step so that next time you upload, it **updates the same map**
instead of making a duplicate. (Claude does this — not you.)

---

## STEP 5 — Make sure it works (play it yourself)

1. Open the **link** from Step 3 in Steam → click **Subscribe** (this downloads the map).
2. Start **Black Ops 3** the normal way.
3. Go to **Zombies** → find **Abandoned Cyber City** in the list → play a round.

---

## STEP 6 — Play with friends

1. **Send your friend the link** from Step 3. (Because it's *Friends Only*, they can also
   just find it in their own Steam Workshop.) They click **Subscribe** and wait for it to
   finish downloading.
2. **You (the host):** start Black Ops 3 → **Zombies** → pick **Abandoned Cyber City** →
   set the game to **Online** (not Solo).
3. **Invite them:** press **Shift + Tab** (Steam overlay) → right-click your friend →
   **Invite to Game**. They accept → you start the match.

**Tips:**
- Both of you must have the map fully downloaded first.
- You both automatically get the same version — no "mismatch" problems.
- Don't try to have friends join your test launches on your PC — co-op only works through
  the **subscribed Workshop map** + a Steam invite (the steps above).

---

## Your two questions, answered

- **"Am I running scripts?"** → **No.** Claude runs every script and builds the map.
  You only click Upload (Step 3) and play.
- **"Where do I go to upload?"** → **Not a website.** Steam → Library →
  *Black Ops III - Mod Tools* → **Play** → **Launcher** → pick the map → **Publish** →
  **Upload**.
