# 04 — The extraction normalizes positions (#984)

Status: ✅ done

Closes [#984](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/984), reported on Discord
by The Reaper and filed by the support bot on 2026-09-22.

## Problem

`AircraftGroupsExtractorWorker._clean_group_data` removes `radio` and `Radio` and nothing else
(`PROPERTIES_TO_EXCLUDE`, line 1041). `x` and `y` survive, at group and unit level, so an extracted
catalogue carries the coordinates of the mission it came from — and those coordinates mean nothing
in another mission, let alone on another theatre.

The proof is in our own shipped file: `veafSpawn-MQ9 - AFAC - JTAC - DRONE` sits at x = −250 000,
y = −360 000. The 128 dynamic-slot templates are at (0,0) only because yesterday's graft normalized
them by hand.

## Decision

Normalize to **(0,0)**, group and unit level.

The issue asks for two different things: its title says "mettre les coordonnées à 0", its body says
"templates injectés au centre de la map". (0,0) is what the shipped catalogue already does, and on
Caucasus it is a real point on the map — north-west, 241 km west of the westernmost airfield,
measured against the bundled parking data. The map centre would need theatre bounds, which this
repository does not hold; it ships airfield positions and nothing that delimits a theatre.

A template is never spawned where it stands — it is late-activated, hidden, and referenced by name —
so the position is a placeholder. What matters is that it is the **same** placeholder everywhere and
carries nothing from the source mission.

Answer in the issue why not the map centre, so the reporter gets the reasoning rather than a silent
partial fix.

## Work

- Zero `x`/`y` on the extracted group and on each of its units.
- Leave `alt`, `heading`/`psi`, speeds and the route alone — only the position is mission-specific
  in a way that travels badly. Route points already carry their own `x`/`y`: zero those too, and say
  in the code why (a route point inherited from another mission is the same defect one level down).

## Tests

- Extract from a mission whose groups sit at real coordinates → every `x`/`y` in the output is 0.
- The rest of the group is byte-identical to what the extractor produces today.
- Round-trip: extracting the shipped catalogue back out changes nothing (it is already at 0).
