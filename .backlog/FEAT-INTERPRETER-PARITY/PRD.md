# FEAT-INTERPRETER-PARITY — interpreter units cannot be randomised, hidden or late-activated

Status: ⬜ ready

Origin: [#25](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/25) and
[#123](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/123) — same file, same absence,
grouped for that reason.

## The gap

`veafInterpreter.lua` contains neither `randomiz`, nor `hidden`, nor `lateActivation`: zero
occurrences of all three.

- **#25** — the randomisable parameters (`veaf.getRandomizableNumeric`, `veaf.lua:3237`) never reach
  interpreter or combat-zone elements.
- **#123** — an interpreter unit cannot be late-activated or hidden on the MFD, which the Mission
  Editor offers on any unit.

## Scope

Attribute plumbing rather than new behaviour: the randomiser exists, and `hiddenOnMFD` is already
threaded through `doSpawnGroup`. The work is exposing them where the interpreter reads its
definitions.

Answer here rather than assume: **do combat-zone elements share that path?** #25 names both, and if
they do, one change covers two surfaces.

## Definition of done

- [ ] An interpreter unit accepts a randomisable numeric where a fixed one works today
- [ ] An interpreter unit can be late-activated and hidden on the MFD
- [ ] The combat-zone-element question answered in writing
