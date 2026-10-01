# 02 — `active_at_start` on a combat operation

Status: ✅ done

Files: `veaf_libs/lua_config_generator.py`, `test/python/veaf_libs/test_lua_config_generator.py`,
`doc/mission-maker/scripts/veafCombatZone*.md`.

The generator emitted `veafCombatZone.ActivateZone(name, true)` for every `active_at_start` entry
**except** operations, since the key was introduced (`fb99d706`, no reason given). `ActivateZone` finds
an operation like any zone (`AddZone` registers it), so the exclusion only made the key silently
ignored on one.

## Done when

- An operation flagged `active_at_start` is activated after `initialize()`, like a zone.
- The operation's table in the combat zone page lists the key, and says that activating an operation
  activates all its zones at once (recorded in `known-limitations.yaml`,
  `operation-spawns-all-its-zones-at-once`).
