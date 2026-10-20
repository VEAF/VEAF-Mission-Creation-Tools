# 03 — docs, known limitations, changelog

Status: ✅ done

Files: the mission-maker pages that say a grid is swept per workstation (`GUIDE`, `AI_ASSISTANT_CATALOG`, `CAMPAIGN`, `CLI_REFERENCE`, fr + en), `known-limitations.yaml` (the Falklands and MarianaIslands entries say "not shipped") (the generated `docs/agents/dcs-runtime-traps.md` renders only the `dcs` entries, so it does not change), `CHANGELOG.md`.

## Done when

- The pages say a grid is downloaded when published, swept otherwise; `poetry run docs-check` passes.
- The limitations say the grid is downloaded where published, and a new entry says a downloaded grid is never refreshed.
