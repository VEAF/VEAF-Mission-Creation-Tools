# CHORE-TOOLING-GATES — version the Foothold batch script, close two tooling traps

Status: ✅ done

## Context

Three items surfaced while shipping `FEAT-FOOTHOLD-RELEASE-INTAKE`, all about tooling rather
than product behaviour. Two are traps that already cost time; one is a helper worth keeping.

1. **The Foothold batch script has no home.** Adopting a Lekaa release means running
   `convert-other` ten times (one archive per map) and picking the right profile for each.
   A PowerShell script doing that in one pass was written for the 4.4.1 adoption and lives in
   a scratch folder — it should be in the repo, since every future release needs it.

2. **`veaf-tools.spec` misrepresents what the executable bundles.** It lists
   `veaf_libs\data\convert-profiles`, yet the build never reads that file: it passes
   `--add-data` from `BuildAndReleaseWorker._veaf_tools_extra_data`. This is exactly what made
   the missing conversion profiles hard to spot — the obvious place to look said the data was
   there. It is a lie waiting to catch the next person.

3. **`test/python/` is not under the ruff gate.** The CI runs
   `ruff check src/python/veaf-tools` only, so the test tree drifts unchecked. Running
   `ruff check test/python/ --fix` today touches 9 MCP test files with real findings — none
   of which any gate would have caught.

## Scope

| # | Ticket | Status |
|---|--------|--------|
| 01 | [Version the Foothold batch script under `tools/`](tickets/01-version-foothold-batch-script.md) | ✅ |
| 02 | [Make `veaf-tools.spec` honest — or delete it](tickets/02-pyinstaller-spec-honesty.md) | ⬜ |
| 03 | [Bring `test/python/` under the ruff gate](tickets/03-ruff-gate-on-tests.md) | ⬜ |

## Notes

Tickets 02 and 03 are independent of each other and of 01; 01 ships first because it is a new
file with no blast radius, while 02 and 03 both touch how the build and the CI are wired.
