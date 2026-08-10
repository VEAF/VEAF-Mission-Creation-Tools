# Collect a map's airbases — step by step

You will: start a small program, open a mission in DCS, type one command. It creates
**one file** to send back to David. **One map at a time.** About 5 minutes.

## Before you start

- **DCS World** installed, with the map to process.
- The **kit**: download `veaf-map-capture-kit-<version>.zip` from the
  [VEAF releases page](https://github.com/VEAF/VEAF-Mission-Creation-Tools/releases)
  and **unzip it into a folder**.
  ⚠️ **Keep everything together, don't move anything**: the programs look for each other.

---

## 0 · A one-time tweak on your DCS ⚠️

By default DCS **forbids** scripts from talking to the outside world. Without this tweak
**nothing will work** (the black window will never show `DCS connected`).

- **Close DCS** completely.
- Open this file in Notepad *(inside your DCS installation folder)*:
  `Scripts\MissionScripting.lua`
- **Delete everything from** the line starting with `local function sanitizeModule(name)`
  **to the end of the file**.
- **Save.**

> 🔁 **Redo it after every DCS update** (updates restore the original file).
> 📖 Details: [dcs-bridge prerequisites](https://github.com/VEAF/VEAF-dcs-bridge/blob/develop/docs/guide/prerequisites.en.md).
> It is the same tweak other well-known DCS scripts require (e.g. the STTS text-to-speech
> module) — if you already did it, there is nothing to redo.

---

## 1 · Start the small server

Double-click **`dcs-serve.exe`**.
→ A **black window** opens and **stays open**. That's normal — **leave it alone** (don't
close it until you're done).

> The window closes by itself? A server is already running: close the other black windows
> and try again.

## 2 · Open the mission in DCS

- Launch **DCS**.
- Open the mission **`missions\bridge-<Map>.miz`** (the one for your map).
- Click **play** ▶, then **pick the "Spectators" slot** and **confirm** to enter the
  mission.
  → No need to fly: the mission just has to be **running**.
- Wait **~5 seconds**. In the black window you should see **`DCS connected`** appear.

> No mission provided for your map? See **"Make the mission yourself"** at the bottom.

## 3 · Run the collection

- Open the **kit folder** in Windows Explorer.
- Right-click in the folder → **"Open in Terminal"**
  *(or: click the address bar, type `cmd`, Enter)*.
- **Copy-paste** this line, then Enter:

  ```
  veaf-tools.exe dcs capture-map --out-dir .
  ```

- → A **`<Map>.json`** file appears in the folder (e.g. `Syria.json`). 🎉

> Nothing to configure: the program picks up the access code created by
> `dcs-serve.exe` on its own (in the `dcs-serve.yaml` file, next to it).

## 4 · Send it

Send that `<Map>.json` file to **David**. Done for this map!

**Next map:** quit the mission in DCS, open the other map's mission, and redo steps
**2 → 4**. (No need to restart the black window, leave it.)

---

## The maps: what's done, what's left

Tick as you go. **No need to redo a map already ticked.**

### ✅ Every current DCS map is covered 🎉

- [x] **Syria** · **Caucasus** · **Cold War Germany** · **Marianas** · **Normandy**
- [x] **Persian Gulf** · **Sinai** — *collected by David*
- [x] **Nevada** · **The Channel** · **South Atlantic** (Falklands) · **Kola**
- [x] **Afghanistan** · **Iraq** · **Marianas WWII** — *collected by Reaper, thanks!*

**So there is nothing left to collect right now.** What we will still need:

- **a brand-new DCS map ships** → collect it (the mission takes two minutes to build in the
  editor, see just below);
- **an existing map gains airfields** in an update → a fresh capture simply replaces the old
  one.

---

## Make the mission yourself (map not provided)

1. In DCS: **Mission Editor** → **New Mission**.
2. Pick the **map**.
3. Place **one aircraft** anywhere *(required — otherwise DCS won't save)*.
4. **Save** as `.miz`. Remember where.
5. In the terminal (like step 3), type *(use your mission's real path)*:

   ```
   veaf-tools.exe dcs inject-bridge "C:\...\my-mission.miz"
   ```

   → Your mission is ready (a backup copy is created automatically next to it).
6. Open that mission in DCS and resume at steps **2 → 4**.

---

## If it gets stuck

| What you see | What to do |
|---|---|
| The black window closes at once | A server is already running — close the other black windows, redo step 1. |
| `cannot reach dcs-serve` | The black window (step 1) isn't open. Restart `dcs-serve.exe`. |
| The black window never shows `DCS connected` | **Step 0 was not done** (or a DCS update undid it). Redo it. |
| `504` or `bridge exec failed` | You didn't **enter** the mission (Spectators slot), or it's still loading. Check the black window shows `DCS connected`, wait 5 s, retry. |
| `no API key found` | `dcs-serve.exe` was never started from this folder (it is what creates the `dcs-serve.yaml` file). Do step 1, then retry. |
| `HTTP 403` | The access code does not match: close the black window, restart `dcs-serve.exe`, retry. |

Anything else? Take a screenshot and send it to David.
