# 04 — A template with no first-waypoint task is named

Status: ✅ done

Type: fix · Files: `src/scripts/veaf/veafSpawnAircraft.lua`, `test/lua/test_veafSpawn.lua`,
`doc/mission-maker/scripts/veafSpawn.md`, `doc/mission-maker/scripts/veafSpawn.en.md`

## What was wrong

`spawnCombatAirPatrol` copies the template's first-waypoint `ComboTask` onto the spawned patrol — that
is where the template's author put his radar setting, his ECM setting and his rules of engagement. When
the template has no such task, `chosenTemplateWp1Task` came back nil and the CAP spawned **in silence**
without any of it.

**12 of the reference mission's 117 `veafSpawn-` templates** are in that state: Mig-21, Mig-23S,
Mig-25, F-14A, F-5, M-2000. Not the cause of what was seen on 2026-09-01 — `f15` and `mig29` are not
among them — but the same family, and invisible until someone went looking.

## What was done

A warning naming the template, and a paragraph in the mission maker's page saying what it means.

**Deliberately not a fabricated default task.** Air-to-air behaviour is set on the *controller* by the
watchdog on every tick — `PROHIBIT_AA` and the rules of engagement both — so a synthesised waypoint task
would add nothing the CAP does not already get. What is actually missing is the template author's own
options, and only he can supply them. Naming the template is what lets him.

## Definition of done

- [x] A template with nothing usable on its first waypoint is named in the DCS log
- [x] Nothing is invented in the template author's place
- [x] The mission maker's page says what the warning means
- [x] Test red before the change, green after
