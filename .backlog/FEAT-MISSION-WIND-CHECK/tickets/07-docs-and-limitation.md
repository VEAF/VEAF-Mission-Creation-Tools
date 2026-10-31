# 07 — Known limitation, documentation, demo mission, CHANGELOG

Status: ⬜ ready

- a. **Known limitation** (`veaf_libs/data/known-limitations.yaml`, `kind: dcs`, dated 2026-10-31, DCS 2.9.31.29434): the editor's ground wind is the 10 m wind only at the sea shore — 2.141 × the setting at 0 m, reduced near the ground less the higher the terrain, about 2.1 × the setting between 300 and 600 m above the ground, and a jet in the low layer when `at2000` is under 2.14 × `atGround`; measured on *Marteau du Golan* (9 m/s set, 24 kt at 10 m above Rosh Pina, 36 kt at 1,000 ft), whitepaper linked.
  A second entry for the layer without wind when the surface and 2,000 m directions are opposed (whitepaper, section 3.3).
  Then `poetry run python -m veaf_libs.known_limitations` regenerates `docs/agents/dcs-runtime-traps.md`, which `describe_known_limitations` serves to an agent without this repository.
- b. **Documentation pages**, FR and EN, each with its `.en.md` twin:
  - `doc/mission-maker/concepts/weather-variants.md`: the wind of a variant is the wind wanted at the reference airfield, how that airfield is chosen, `reference_airfield`, `wind_veer`, the explicit upper layers, `clearsky` capping the simulated wind, gusts;
  - `doc/mission-maker/scripts/veafWeather.md`: rounded speeds, the max-wind line, the gust option;
  - `doc/developer/mission-editing-mcp.md`: `set_weather`'s new parameters and answer;
  - the `mission-check` page: the wind check (written with ticket 05);
  - `doc/PIPELINE_REFERENCE.md` where it describes the weather injection;
  - each page links the whitepaper for the why, with an explicit English anchor where a section is linked (CLAUDE.md §7).
  `poetry run docs-check` green; if a page is added or retitled, the support bot's index is refreshed (`services/support-bot`, `refresh_doc_pages.py`).
- c. **Demo mission** ([`VEAF/VEAF-Demo-Mission-v6`](https://github.com/VEAF/VEAF-Demo-Mission-v6), CLAUDE.md §9 item 9): one step in `tour/steps.yaml` where the player asks the ATIS of an airfield under a wind with a low-layer peak and reads the max-wind line, with its acceptance check; the demo's weather set through the new path so the ATIS surface wind matches its briefing.
- d. **CHANGELOG** under `[Unreleased]`, one entry at the end of the section: the wind written as wanted, described as simulated, checked by `mission-check`, and the ATIS changes.

Done when: the traps page carries both entries, `docs-check` is green, the demo step is merged in its repository (or its PR linked from this lot's PR), and the CHANGELOG entry is in.
