# 01 — the two prompts, in French and English, ask for both carriers

Status: 🧑 waiting-human

Files: `src/python/veaf-tools/veaf_mission_mcp/data/mission-prompts/new-open-training-mission.fr.md`, `src/python/veaf-tools/veaf_mission_mcp/data/mission-prompts/new-open-training-mission.en.md`,
`src/python/veaf-tools/veaf_mission_mcp/data/mission-prompts/new-objective-mission.fr.md`, `src/python/veaf-tools/veaf_mission_mcp/data/mission-prompts/new-objective-mission.en.md`, `CHANGELOG.md`.

## Done when

- Each of the four prompts says, where it describes the carrier group, that a generated mission with a
  carrier group always gets two: the Stennis and the Roosevelt, one `add_carrier_group` each, with
  distinct TACAN, ICLS, Link 4 and frequencies — and that it is David's decision of 2026-10-02.
- `CHANGELOG.md` says so under `[Unreleased]`.
