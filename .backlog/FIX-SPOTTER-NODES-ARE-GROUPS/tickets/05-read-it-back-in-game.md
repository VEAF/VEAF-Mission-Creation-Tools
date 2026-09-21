# 05 — Read it back in game

Status: ✅ done — read back in game 2026-09-21

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

## What was actually done, and it went further than the ticket asked

Two convoys were not enough to be worth the trip, so a **whole mission** was built for it:
`test/veaf-tools/spotter-network-dense/`, Syria, anchored on Palmyra — 26 groups and 71 units, a
screen of six observation posts over 95 km of front, two clusters packed the way a combat zone is
packed, three air patrols, and a real combat zone absent until activated.

Measured in game on 2026-09-21:

| | per group (measured) | per unit (the old model) |
|---|---|---|
| nodes | **21**, then **26** with the combat zone activated | 57, then 71 |
| links | **65–67**, then **78–83** | 576, then 713 |
| shapes drawn | **103–135** | ~690–855, against a budget of **400** |

So the mission would have been truncated by construction under the old model. David read the map
colour by colour and confirmed each shape, including the **red square and red envelope** of a battery
going live — the one shape that never drew at all before the review fix in `14cfc288`.

Three things learned doing it, each written where it belongs:

- **A red combat zone's radio menu goes to BLUE.** `getRadioMenuCoalition` falls back to the zone's
  *friendly* coalition — the side that attacks it — so a **red** game master sees the `ZONES DE
  COMBAT` root and nothing inside it. Not a defect; it cost a round of puzzlement, and activating
  from the bridge is the right route for a red-side test.
- **The combat zone respawns its groups under generated names** (`[r]-Canyon Platoon#25205`), and the
  graph picks them up as five groups rather than fourteen units.
- **The intruder was spawning at heading 0 with a route running south**, so it flew away, turned
  round, and arrived a minute late — long enough for a measurement window to close on "nobody sees
  it" and for me to raise a false alarm against working code. Fixed in both missions.

## Definition of done

- [x] Node and link counts measured in game, and they match ticket 03.
- [x] The picture is legible at 26 groups, and David says so.
- [x] No truncation: 135 shapes at the busiest, against a budget of 400.
