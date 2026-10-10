# 01 — `RADIO.menu_stats`: log the F10 menu's size and changes

Status: ✅ done

## Done when

- `modules.RADIO.menu_stats: true` reaches `veaf.config.RADIO` (generic `setConfig`), off by default.
- With it on, every `RadioMenuBuilder:rebuild()` logs one `info` line: entries added and removed since the last line, live entries split by audience (everyone, coalitions, groups, and how many groups), parked ids in all. An unchanged rebuild logs too.
- With it off, nothing is logged.
- Lua tests on the mocks, each mutation-checked; a generator test pins the `setConfig` line.
- `veafRadio` page FR/EN, `MISSION_YAML_REFERENCE` FR/EN, the shipped `mission.yaml` comment.
