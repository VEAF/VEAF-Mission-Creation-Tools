# 07 — Carrier: option not to start the VEAF 60 s loop

Status: ⬜ ready

## Done when

- `modules.CARRIER.init.operations_scheduler: false` initializes the carriers and their menu without starting `operationsScheduler`.
- Absent, the generated call is unchanged.
- Python and Lua tests, `MISSION_YAML_REFERENCE` FR/EN; checked on a converted BFR part.
