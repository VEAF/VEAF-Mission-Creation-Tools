# 04 — The build says which modules it picked up

Status: ✅ done

Type: feat

## The problem

A mission maker who adds a module to `mission.yaml` has no way to tell from the build whether it was
read. The only line about the generated configuration is

> Generated 'veaf-config.lua' from mission.yaml

([`mission_builder_worker.py:2488`](../../../src/python/veaf-tools/mission_builder/mission_builder_worker.py)).
Paluche added a combat zone and got no acknowledgement of it; the next thing that could have told him
anything was the F10 menu, in game, after a load.

`validate` is not the answer on its own: it is silent on success by design, so "0 errors" says the
YAML is coherent, not that COMBATZONE reached the mission.

## What to log

One `info` line after `veaf-config.lua` is written, naming the modules actually active, and for the
ones that carry a list, how many entries they carry — combat zones, QRA definitions, assets,
airwave zones, sanctuary zones. Counts are what catch the real mistake: a `combat_zones:` list that
resolved to nothing looks exactly like a healthy build today.

Rules:

- Report what was **resolved**, not what the file contains, so the line cannot drift from the Lua.
- No line per module; one line the eye can take in.
- Say nothing extra when nothing is configured — a message every build prints is a message nobody
  reads (the shape `reportGroupsExcludedByName` already uses).

## Definition of done

- [x] The build reports active modules, with entry counts for the list-shaped ones
- [x] The message is in both locale catalogues
- [x] Unit test on the reporting, including the "nothing configured" case
- [x] `--cov-fail-under` bumped per the ratchet policy in `CLAUDE.md`
- [x] Python gate clean (`ruff check`, `ruff format --check`, `mypy`)
