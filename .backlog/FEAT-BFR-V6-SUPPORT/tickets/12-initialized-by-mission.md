# 12 — Module loaded and configured, initialized by the mission

Status: ⬜ ready

A module active in `modules:` is initialized by the generated `veaf-config.lua`; a mission layer that initializes it too gets it twice.
`false` is no answer for SKYNET and CTLD: it also drops the community script.

## Done when

- `initialized_by_mission: true` (PRD decision a) keeps the script and the configuration, and emits no `initialize()` call; accepted under `modules.<ID>`, `external_modules.skynet`, `external_modules.csar`, `community_scripts.ctld`.
- The registry path is cut too: `veaf.initialize()` skips such a module.
- Python and Lua tests, `MISSION_YAML_REFERENCE` FR/EN; checked on a converted BFR part.
