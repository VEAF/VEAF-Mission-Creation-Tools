# FEAT-WAYPOINT-BULLSEYE — inject the bullseye as a waypoint automatically

Status: ⬜ ready

Origin: [#175](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/175), 2023.

## The gap

The ask is small: a named point called `BULLSEYE` should be injected as a waypoint without the mission
maker listing it.

`BULLSEYE` appears in `waypoints_injector_README.py` — as an **example** of a named point in the
documentation — and nowhere in `waypoints_injector_worker.py`. So the injector will happily inject a
bullseye you declare, and does nothing on its own.

## Scope

Inject the theatre's bullseye per coalition, unless the mission already declares a waypoint of that
name. Two things to settle by reading rather than guessing:

- **Where the bullseye comes from.** A `.miz` carries `coalition.<side>.bullseye` in the mission
  table, so it need not be computed — but check which side's bullseye a given flight should get.
  `FIX-CASMISSION-BLUE-BULLSEYE` (issue #304, closed) was exactly a bug about using the wrong one.
- **Whether it should be on by default.** An extra waypoint in every flight plan is a visible change
  for every mission that rebuilds. Opt-in is the safe default; opt-out is what the issue implies.
  Decide and record it.

## Definition of done

- [ ] A flight gets a `BULLSEYE` waypoint without declaring one
- [ ] The correct coalition's bullseye, with a test per side
- [ ] A mission that declares its own `BULLSEYE` is not given a second one
- [ ] The on-by-default question answered here, not left to the implementation
- [ ] Documented, both languages
