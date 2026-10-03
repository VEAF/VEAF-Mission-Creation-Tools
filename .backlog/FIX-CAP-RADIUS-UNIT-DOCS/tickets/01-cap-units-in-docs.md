# 01 — correct the units in the CAP docs

Status: 🔄 in-progress

`doc/mission-maker/scripts/veafSpawn{,.en}.md` (CAP options and example), `doc/pilot/GUIDE{,.en}.md`
(example) and `doc/LUA_API_REFERENCE{,.en}.md` (`spawnCombatAirPatrol` parameters): `capradius` and
`distance` in nautical miles with their defaults (60 and 20), example `capradius 20`, FR and EN in step.

## Acceptance

- No page gives `capradius` of a `-cap` in metres; `poetry run docs-check` passes.
