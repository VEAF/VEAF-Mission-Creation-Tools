# Lot CHORE-TOOLING-GATES — version the Foothold batch script, close two tooling traps

Status: ✅ done

**Goal**: three items surfaced while shipping `FEAT-FOOTHOLD-RELEASE-INTAKE`, all about tooling rather
than product behaviour. Two were traps that had already cost time.

| # | Ticket | Status |
|---|--------|--------|
| 01 | Version the Foothold batch script under `tools/` | ✅ |
| 02 | Make `veaf-tools.spec` honest — or delete it | ✅ |
| 03 | Bring `test/python/` under the ruff gate | ✅ |
| 04 | Bring `test/lua/` under the StyLua gate | ✅ |

## The two traps

**`veaf-tools.spec` misrepresented what the executable bundles.** It listed the
`veaf_libs/data/convert-profiles` directory, yet the build never reads that file — it passes
`--add-data` from `BuildAndReleaseWorker._veaf_tools_extra_data`. That is precisely what made the
missing conversion profiles hard to spot: **the obvious place to look said the data was there.** A lie
waiting to catch the next person.

**`test/python/` was outside the ruff gate.** CI ran `ruff check src/python/veaf-tools` only, so the
test tree drifted unchecked. Running it for the first time touched **9 MCP test files with real
findings** — none of which any gate would have caught. `test/lua/` had the same hole for StyLua.

**The Foothold batch script had no home.** Adopting a Lekaa release means running `convert-other` ten
times, one archive per map, with the right profile for each. The PowerShell script that does it in one
pass was written for the 4.4.1 adoption and lived in a scratch folder; every future release needs it,
so it is versioned under `tools/`.

## Sequencing note

Tickets 02 and 03 were independent of each other and of 01. 01 shipped first because it is a new file
with no blast radius, while 02 and 03 both touch how the build and the CI are wired.
