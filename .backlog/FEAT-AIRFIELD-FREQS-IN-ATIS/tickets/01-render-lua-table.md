# 01 — the reference is rendered as a Lua table the scripts load

Status: ⬜ ready

The mission scripts cannot ask DCS for an airfield's frequencies (see PRD). The reference the tools
already ship can be handed to them instead.

## Done when

- `veaf-build update-dcs-data --airfield-freqs` also renders `src/scripts/veaf/veafAirfieldFrequencies.lua`
  from `airfield-frequencies.yaml`: theatre (`env.mission.theatre`) -> airdrome id -> `{ uhf, vhf, fm,
  tacan }`, with the `GENERATED … DO NOT EDIT` header `veafCities.lua` carries.
- A test fails when the committed Lua file differs from what the YAML renders (the `veafCities.lua`
  guard is the model: `veaf_build/dcs_data/cities.py`).
- The file is loaded with the other VEAF scripts, before `veafWeather`, in the build **and** in
  `--dev-mode`; `stylua` exclusion as for `veafCities.lua` if its size requires it.
- A small accessor (`veafAirbases.getAtcFrequencies(dcsAirbase)` or similar) returns the entry for the
  mission's theatre and the airbase's id, `nil` for a ship, a FARP or an unknown field — tested on the mocks.
