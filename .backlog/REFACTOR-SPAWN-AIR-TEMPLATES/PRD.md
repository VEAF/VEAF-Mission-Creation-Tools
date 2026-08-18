# REFACTOR-SPAWN-AIR-TEMPLATES — rationalise how an air template is chosen

Status: ⏸ paused — no player-visible symptom; do it when someone is already in this code.

Origin: [#284](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/284), MacFlorent, 2025-01,
with screenshots and a five-comment discussion on the issue.

## The problem he describes

`veafSpawn.findSpawnableAircraftGroupname` picks from every mission group whose name starts with
`veafSpawn-`. That makes the mission's own group naming the API, and the selection rules hard to
follow — his words and his examples are on the issue and are the specification.

## Why it is paused rather than ready

There is **no symptom a player or mission maker sees**: it is maintainability. A refactor with no
trigger competes with work that fixes something, and loses — while carrying real risk, since template
selection decides what a `-cap` actually spawns.

**Unpause it** when a lot touches air spawning for another reason (a CAP lot from the DCS verification
session is the likely one). Doing it then costs the reading twice rather than three times.

## Scope

MacFlorent's analysis is the input. The lot must produce, before changing anything, the current
selection rules **written down** — the discussion suggests nobody has them in one place, which is
itself the finding.

## Definition of done

- [ ] Current selection rules written down and confirmed against the code
- [ ] The new rules stated, with what changes for an existing mission
- [ ] `-cap` and the other air spawners produce the same groups as before, proven by test
