# 12 — A circular sanctuary from mission.yaml

Status: ✅ done

Files: `veaf_libs/lua_config_generator.py` (SANCTUARY), the validator, `doc/mission-maker/scripts/veafSanctuary.md`,
`.prompts/new-open-training-mission.*.md`, tests.

## What happened

`veafSanctuary` builds a zone from a polygon, a circle (`setPosition` + `setRadius`) or a trigger zone
(`addZoneFromTriggerZone`), but `sanctuary_zones[]` only reads `polygon_units`. Seventeen sanctuaries round
the Syria bases took 102 late-activated vertex units.

## Done when

- A sanctuary entry takes `trigger_zone: <name>` as an alternative to `polygon_units`, exactly one of the two,
  refused otherwise.
- The prompt prefers the trigger zone for a base's sanctuary.
