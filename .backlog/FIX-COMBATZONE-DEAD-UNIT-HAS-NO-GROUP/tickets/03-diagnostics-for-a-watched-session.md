# 03 — diagnostics for a watched session

Status: 🧑 waiting-human — built 2026-09-28; the evening session on the server is the measurement.
Type: instrumentation

## Why

David, 2026-09-28: he asked for the zone's information **right after activating it**, and is 95 %
sure the list was short — *"quelques camions et une Shilka"*. The sortie's log says the zone spawned
all fifteen vehicles in one frame, one second before the automatic panel, and the code as read lists
all fifteen. The two cannot both be right, and nothing the zone knows is logged at `info`, which is
the level the server runs at. The mission and the code have both moved since, so a local
reproduction would not measure the same thing.

David's call: instrument the log, run the new mission on the server tonight, and watch it live.

## What was built

- **`veaf.Diagnostics`** (default `false`) and **`veaf.diag(loggerId, text, ...)`**, in `veaf.lua`.
  A line is written at `info` whatever the module's own level, marked `DIAG|`. Switched on from
  `mission.yaml` through the existing hatch — no generator change:

  ```yaml
  module_settings:
    veaf.Diagnostics: true
  ```

- **Combat zones**, every step that decides what the zone holds or says:
  - the activation request, and whether it was taken, ignored (already active) or unknown;
  - activation start (elements, groups already registered) and end (every registered group);
  - each element: the group it became with its live units and types, a spawn that FAILED (logged at
    `trace` until now, so invisible), a delayed spawn, a missed `#spawnchance` draw, a `#command` and
    the group it produced;
  - the info panel: who asked, what it sees group by group, any unit type it does not count, and the
    exact text it sends;
  - each watchdog pass: what it sees group by group, the tallies, and its decision;
  - deactivation, with the number of groups destroyed.

## What to read tonight

Filter `dcs.log` on `DIAG|` and on the zone's name. The line that answers the question is
`panel sees …` right after `panel requested by the activation (everyone)`: it says, for each group,
whether DCS knew it at that instant and what was alive in it.

## Definition of done

- [x] Tests: the switch writes nothing when off, writes past a module's `warning` level when on, and
      each combat zone line appears with the values it claims (`test_veafDiagnostics.lua`)
- [x] Documented on the combat zone page (`#diagnostics`), in both languages
- [ ] Measured on the server: the panel content right after activation, recorded here
