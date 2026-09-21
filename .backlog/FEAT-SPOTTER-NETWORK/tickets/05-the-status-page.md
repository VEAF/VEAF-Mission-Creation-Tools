# 05 — The status page

Status: ⬜ ready

A status page in the log, on the model of Skynet's and **toggled the same way** — the `debug_red` /
`debug_blue` flags that already reach `initializeIADS` and set `iadsDebug.IADSStatus`
(`veafSkynetIadsHelper.lua:1585-1600`). No new switch.

## Why this is not optional decoration

Once this ships there will be **three** reasons a site can light up: an early-warning radar, the
last line of defence, or a spotter. An unexplained wake-up is already the single most common report
on this subject, and with three causes and no trace the question becomes undecidable — for us and
for the mission maker.

## What it prints

- **The graph**: node and edge counts, and the number of connected components. The component count
  is the one that answers "why did my alert not travel", which the connectivity measurements say
  will be the common case on a scattered mission — at 20 km a spread-out map still only connects
  8.8 % of its units into the largest pocket.
- **Live alerts**: the aircraft, and the **age** of the alert. Age is what distinguishes a contact
  being refreshed from one about to be forgotten by the heartbeat net.
- **Spotters that acquired this cycle** — who saw it, so a report can be traced back to an eye.
- **Sites woken, and by which alert** — the other end of the same thread.

Print it at the same cadence Skynet prints its own status, so the two read together in `dcs.log`
rather than interleaving at different rhythms.

## What not to do

Do not make the page compute anything it is reporting on. Counting edges is O(edges) and the dense
front carries 230 577 of them — cheap enough once per status print, and absurd if a counter can be
kept up to date by the graph loops that already touch every edge. If the page needs a figure nobody
maintains, maintain it in ticket 02's code rather than recomputing it here.

## Tests

- With the debug flag off, nothing is written. A status page that prints regardless is a log flood
  in every mission that never asked for it.
- With it on, the page names the aircraft, the spotter that acquired it and the site woken — assert
  against the captured log text, not against an internal table, because the point of this ticket is
  what a human reads.
- An alert's age grows across beats and is reported, so a stale contact is visibly stale.
- **Wiring**: the page is actually scheduled when the flag is on.

## Definition of done

- The status page written, behind the existing debug flags.
- The tests above.
- A line in `doc/mission-maker/scripts/veafSkynetIadsHelper.md` and `.en.md` saying how to turn it
  on and how to read it — three causes for a wake-up is exactly the thing a mission maker needs told
  in advance, and `doc/mission-maker/LOGS.md` is where they will look for it.
- `poetry run test-lua` green, `stylua --check src/scripts/veaf/ test/lua/` clean, `poetry run
  docs-check` after touching `doc/`, Lua coverage floor bumped.
- `CHANGELOG.md` updated under `[Unreleased]`, appended at the end of the section.
