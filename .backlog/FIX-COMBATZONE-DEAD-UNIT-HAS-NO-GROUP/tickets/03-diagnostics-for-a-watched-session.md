# 03 — diagnostics for a watched session

Status: ✅ done — measured 2026-09-29 from the `private1` log of the 2026-09-28 evening session; it
found a real defect, fixed in this lot.
Type: instrumentation

## 2026-09-29 — what the session measured

`private1_server/Logs/dcs.log`, GermanyCW `_20260928`, 1 743 `DIAG|` lines. Zones activated:
**WahnerHeide_Hard** (19:34:29), **Borkenberge_Medium** (19:46), **WahnerHeide_Easy** (next day
11:21:43).

- **The panel right after activation listed everything the zone knew as a group.** Hard, one second
  after activation: 9 groups registered, the panel sees all of them and writes *"35 véhicule(s)
  restants"* with the 16 types — `-aaa` (2 Ural-375 ZU-23 + a Shilka), `-blindes` (5), and the two
  `#command` groups (10 + 17). *"Quelques camions et une Shilka"* is not what this panel said; it is
  what `-aaa` alone looks like.
- **But the panel skipped every static.** The five `-cible-N` elements now spawn as **statics**
  (`panel sees [r]-Swift Hawk#10414 #72: static`). `getInformation` only read `Group.getByName`, so
  they were not in the text; `completionCheck` reads `StaticObject.getByName` too and waited for
  them — Hard's first watchdog pass: `enemies=40` = 35 vehicles + 5 statics.
- **Easy made it plain:** its five elements are all statics, and its panel had no ENEMIES line at
  all while the watchdog counted `enemies=5`. A zone telling the players there is nothing left, and
  never completing.
- **Borkenberge_Medium completed as designed**: panel 13 → 4 → 1 vehicles, watchdog `enemies=0,
  complete` at 20:45:54, deactivated with its 2 groups destroyed. The completion path works.
- No `spawn FAILED`, no `not counted`, no delayed spawn anywhere.

Fixed in this lot: the panel counts spawned statics, as the watchdog does (structures, with their
type in training mode).

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
- [x] Measured on the server: the panel content right after activation, recorded here
