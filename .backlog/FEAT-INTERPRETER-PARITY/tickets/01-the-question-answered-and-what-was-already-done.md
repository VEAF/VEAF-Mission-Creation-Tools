# 01 — The question answered, and the half that was already built

Status: ✅ done
Type: doc

The PRD says *"answer here rather than assume: do combat-zone elements share that path?"*. Answering it
first, because it decides what the other tickets have to do.

## #25 — randomisable numerics

**Already done for the interpreter, by `REFACTOR-MARKER-PARSER`.** An interpreter command is a marker
command: `veafInterpreter.execute` hands it to `veafCommands.execute`, which parses it with the shared
marker rules, and `veaf.markerRules.number` converts through **`veaf.getRandomizableNumeric`**
(`veaf.lua:3279`) — the very function #25 pointed at. So `#veafInterpreter["_spawn group, name x, size
3-8"]` already draws a size between 3 and 8. Nothing to build; something to prove with a test.

**Not done for combat-zone *tags*.** They are not marker commands. `veafCombatZone.TAG_PATTERNS`
captures `(%d+)`, so `#spawnradius=100-300` matches **`100`** and the `-300` is dropped with no warning:
the mission maker gets the lower bound and is never told. That is where #25 still has work, and it is
worse than "unsupported" — it is silently truncated.

## #123 — late activation and hidden

**Hidden needs nothing.** `hiddenOnMFD` is a mission-editor property of the trigger unit. The
interpreter reads a name and a position; it neither reads nor writes that flag, so a mission maker can
tick the box today and the trigger still fires.

**Late activation is a real gap**, and ticket 03 covers it.

## Definition of done

- [x] A test proves an interpreter command accepts a randomisable numeric
- [x] The combat-zone answer recorded in the PRD, both halves
