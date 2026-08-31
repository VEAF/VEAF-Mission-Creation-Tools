# 01 — Say which groups the zone ignored

Status: ✅ done

Type: fix · File: `src/scripts/veaf/veafCombatZone.lua`

## The change

`findUnitsInCombatZone` walks every unit inside the trigger zone and keeps those whose group name
starts with the zone name. Collect the ones it drops, and report them once per zone at `info`.

Requirements that matter more than the wording:

- **One line per zone, not per unit.** A zone can hold dozens of units of a handful of groups.
- **Nothing at all when nothing is excluded** — a message every mission prints is a message nobody
  reads.
- The text must say *why* and *what to do*: the group name has to start with the zone name.
- Group names, not unit names: that is what the maker has to rename.

Both languages, through the i18n catalogue like the rest of the module.

## Definition of done

- [x] A zone containing a wrongly-named group logs it at `info`, naming the group and the zone
- [x] A zone whose groups are all correctly named logs nothing
- [x] Several excluded groups produce one line, not one line each
- [x] Tests assert what `activate()` (or the build-up path) actually logged, through the mocks
- [x] `poetry run test-lua` green, `stylua --check src/scripts/veaf/ test/lua/` clean
