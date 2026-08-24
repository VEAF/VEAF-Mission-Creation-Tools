# CHORE-TESTING-DOC-COUNTS — the test-count table is hand-written, so it is wrong

Status: ✅ done — shipped in 6.15.19

Found on 2026-08-21 while shipping `FIX-REMOTE-SLOT-NIL-UNIT`, which had to touch two of its rows.

## The problem

`doc/TESTING.md` and `doc/TESTING.en.md` carry a table of "how many tests each Lua suite has". Every
number is typed by hand and nothing checks it, so it decays with every lot that adds a test. Measured
today across the 37 suites: **16 rows are wrong and one suite is missing entirely**.

| Suite | Documented | Actual |
|---|---|---|
| `test_veafCombatZone.lua` | 138 | **214** |
| `test_veafSkynetIadsHelper.lua` | 68 | **102** |
| `test_veaf.lua` | 346 | **379** |
| `test_veafGrass.lua` | 16 | **36** |
| `test_veafMove.lua` | 78 | **92** |
| `test_veafRemote.lua` | 23 | **35** |
| `test_veafSpawn.lua` | 184 | 189 |
| `test_veafWeather.lua` | 107 | 110 |
| `test_veafCombatMission.lua` | 116 | 119 |
| `test_veafCommands.lua` | 17 | 23 |
| `test_veafCarrierOperations.lua` | 47 | 51 |
| `test_veafTransportMission.lua` | 52 | 55 |
| `test_veafAssets.lua` | 26 | 29 |
| `test_veafRadio.lua` | 127 | 128 |
| `test_veafServerHook.lua` | 9 | **14** |
| `test_veafMove_escort.lua` | *absent* | 12 |

The two rows `FIX-REMOTE-SLOT-NIL-UNIT` touched were corrected in that lot. The other fourteen were
deliberately left: correcting them by hand fixes today and guarantees tomorrow's drift.

## Why it matters, modestly

Nobody makes a decision on these numbers, so this is not a defect with a victim. What it costs is
credibility: a reference page whose figures are visibly stale teaches a reader not to trust the page, and
this is the **same shape** the repository already solved once — `CLAUDE.md` forbids hand-writing a version
in a page header precisely because `veaf_build/docs_version_stamp.py` can stamp it.

## Options

1. **Drop the counts, keep the descriptions.** Cheapest and honest: the column nobody uses disappears and
   cannot rot. The table's value is "which suite covers what", not the arithmetic.
2. **Generate the table**, as the docs are already generated elsewhere (`TOOLING-DOC-AUTOGEN` set the
   precedent), and have `docs-check` fail on a stale count.
3. Correct the sixteen rows by hand and change nothing else — rejected: it is what has been done before
   and the table is wrong again a fortnight later.

Recommendation: **1**, unless someone actually reads the numbers, in which case 2.

## What shipped: 1, plus a gate on what was left

**Option 1 for the counts.** The column is gone from both pages, and so are the two other
hand-written totals nobody had noticed were wrong either — "36 Lua test suites" in the overview and
"(36 files)" in the file layout, against 37 actual.

**Beyond the DoD, deliberately:** dropping the counts leaves the *list* of suites still
hand-maintained, and that list is what had actually lost something — `test_veafMove_escort.lua` was
missing, silently, from the day the suite shipped. So `docs-check` now reports a suite absent from
either testing page. It cost one field: `CoverageRule` already did exactly this job for MCP actions,
marker aliases and CLI commands, and only needed to read a file **name** rather than a file's contents
(`from_filename`). A suite nobody documented is coverage nobody knows exists; an arithmetic total is
not worth a gate, which is why the counts were dropped instead of generated.

The gate was verified in both directions rather than assumed green — deleting the escort row makes
`docs-check` report it and fails a test, restoring it clears both. That check exists because this
module has already shipped a rule that silently extracted **zero** names and passed.

## Measured again at closing time, and the figure had moved

| | Rows wrong | Source |
|---|---|---|
| 2026-08-21, when this PRD was written | 16 of 36 | the table above |
| 2026-08-21, when the column was dropped | **12 of 36** | `test-lua` vs `HEAD:doc/TESTING.md` |

Four rows had been repaired by hand in between, by `FIX-REMOTE-SLOT-NIL-UNIT` and
`FEAT-SPAWN-OPTION-VALIDATION` touching suites they happened to change. The drift also showed a row the
PRD's own list had missed (`test_veafGroundAI.lua`, 83 documented for 84). Both facts argue the same
way: a hand-kept number is repaired where someone happens to look, and wrong everywhere else.

## Definition of done

- [x] The counts are either gone or generated — **gone**
- [x] `test_veafMove_escort.lua` is no longer missing from the table
- [x] Both language pages, and `poetry run docs-check` green
- [x] Beyond the DoD: the suite list is guarded, so the table cannot lose another suite in silence
