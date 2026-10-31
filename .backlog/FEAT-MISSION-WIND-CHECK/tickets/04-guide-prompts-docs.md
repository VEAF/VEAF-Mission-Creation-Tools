# 04 — guide, prompts, known limitation, documentation

Status: ⬜ ready

- a. **Known limitation** (`veaf_libs/data/known-limitations.yaml`, `kind: dcs`, dated 2026-10-31): the set ground wind is not the simulated one — 9 m/s set gave 24 kt at 10 m above Rosh Pina and 34 to 37 kt between 150 and 600 m above the ground, falling back towards `at2000` above; regenerate `docs/agents/dcs-runtime-traps.md`. `describe_known_limitations` then serves it to an agent without this repository.
- b. **Authoring guide** (`authoring-guide.md`, "Helicopters fly" and "Finish: validate, then build") and **both mission prompts** (`new-objective-mission`, `new-open-training-mission`, FR and EN, weather of §4.2 and checks of §8):
  - the rule "10 kt or less at the surface" speaks of the **simulated** low-layer wind, not of the setting; a setting near 5 m/s at the surface is a starting point, to be measured;
  - the briefing's wind is the **measured** one, never the `set_weather` values copied; until it is measured, the briefing says so in the Mission Maker notes, not to the pilots;
  - `veaf-tools dcs mission-check` (its wind lines) is part of "what remains to be checked in DCS", run when the user has launched the test copy.
- c. **Documentation** of `mission-check` (FR and EN pages): the wind check, its places and heights, the thresholds and what fails versus what warns.
- d. **CHANGELOG** under `[Unreleased]`, at the end of the section.

Done when: `poetry run docs-check` is green, the regenerated traps page carries the entry, and the four prompt files and the guide no longer state a wind threshold in terms of the setting.
