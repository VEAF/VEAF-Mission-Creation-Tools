# 01 — `mission.forced_options`: the enforced mission options from `mission.yaml`

Status: ✅ done

## Done when

- `mission.forced_options` in `mission.yaml` is written into the mission's `forcedOptions` at every build, each option under its DCS key and value; an option the block does not name keeps the mission's value; no block, nothing touched.
- Every enforceable option of `optionsDb.lua` has a name, with its values translated where DCS stores a code (`labels`, `spotting_dot`, `f10_view`, `civil_traffic`).
- An unknown option, a value of the wrong type or out of its list: `validate` reports it and the build stops, with the same messages.
- Python tests, FR/EN messages, `MISSION_YAML_REFERENCE` FR/EN, the commented example in the shipped `mission.yaml` and in the generated one.
