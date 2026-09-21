# 05 — Read it back in game

Status: 🧑 waiting-human — **needs DCS**

A refactor whose whole justification is a picture nobody could read has to be re-read in the picture.

## Procedure

`dcs-serve` is mine to run, from a folder I control with a key I set, in loopback — see the
[[dcs-bridge-and-fiddle-setup]] memory. Everything except flying and looking is mine.

1. Rebuild and install `spotter-network-walkthrough`, then **remove the `build:` block the build
   writes back into `mission.yaml`** — it carries an absolute path and it has already been committed
   once by accident.
2. David loads it as **Game Master red** and **reopens the F10 map after loading**: a scripted drawing
   does not appear on an already-open map. He *can* toggle the view from the F10 menu — the submenu is
   coalition-scoped, not `USAGE_ForGroup`, so a game master reaches it.
3. Spawn the two transport groups that found the defect — `-transport, armor 0, defense 0, side red` —
   linking `SamIsolated` into the network.
4. Spawn the target **invisible**, not immortal. Measured 2026-09-21, and it is the right design for
   this rig: a site goes live because it was **told**, not because it sees, so `SetInvisible` lets a
   battery light up and show its envelope while never spending its magazine. An immortal target does
   the opposite — `SamCentre` emptied all 12 of its missiles into one, and a site with no ammunition
   never goes live again (`hasRemainingAmmo` false; David spotted it as `noAmmo = 1`). Weapons hold is
   **not** an alternative: Skynet sets ROE back to free whenever it brings a site live, so a hold set
   beforehand does not hold.
5. Read the graph out from inside the mission — nodes, the groups behind them, links — and compare
   against ticket 03's table. Read it in **one** call from a global a scheduled recorder filled;
   a sequence of bridge round trips outlives nothing and cost most of an afternoon.

## Definition of done

- [ ] Node and link counts measured in game match ticket 03.
- [ ] The picture is legible with two convoys on the map, and David says so.
- [ ] No `SpotterViewMaxShapes` truncation warning in `dcs.log` for this mission.
