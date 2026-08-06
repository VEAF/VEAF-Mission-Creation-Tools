# 02 — Coverage check instead of an MCP catalogue generator

Status: ✅ done
Type: feat
Files: `veaf_build/docs_check.py`, `doc/developer/mission-editing-mcp.{md,en.md}`, `test/`

## Why generation was wrong, and which page is the right one

The ticket aimed at `AI_ASSISTANT_CATALOG.md`. That page is 367 lines written **for mission makers in
natural language**, and it says outright that you do not need to know the technical names — only 3 of
the 29 action names appear in it. It also carries an editorial *frequency* column and an explanation
of the recipe-versus-built-`.miz` distinction, neither of which exists in `ActionSpec` (`name`,
`description`, `parameters_schema`). Generating it, or even name-checking it, would be requiring the
page to stop doing its job.

The **technical** page, `developer/mission-editing-mcp.md`, is the one that means to be exhaustive: it
named 28 of 29. So it is the coverage target, and the one action it was missing is the defect this
ticket existed to catch.

## Delivered

- [x] `CoverageRule` for the MCP actions → `doc/developer/mission-editing-mcp.{md,en.md}`.
- [x] Names read by **regex, not import**: the CI job runs `docs_check` with plain `python` and no
      Poetry install, and importing the catalogue would drag in pydantic. A pytest test asserts the
      regex and the real `list_catalog()` return identical sets, so the cheap gate is gated by the
      expensive one — with a failure message naming which side has drifted.
- [x] **`set_airbase_coalition` documented** in both languages, with the trap that motivates it: an
      airfield's coalition lives in `warehouses.airports[<id>].coalition`, not `mission.coalition`, so
      placing a unit near a base never turns the base.
- [x] `AI_ASSISTANT_CATALOG.md` explicitly **not** covered, with the reason recorded next to the rules.

## Acceptance criteria

- [x] Reported 2 gaps before, zero after.
- [x] The regex-versus-catalogue test passes: 29 = 29, identical sets.
- [x] `ruff`, `ruff format`, `mypy` clean.
