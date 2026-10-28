# CHORE-CI-PYTHON-SPEED — the Python suite back under eight minutes in CI

Status: 🔄 in progress

Origin: 2026-10-28, David.
The `pytest` step of `python-quality` went from 5 min (2026-10-12) to 7 min (10-20), 13 min (10-24) and 21 to 25 min (10-28), while the suite grew by 4 % (7 130 → 7 442 tests).
The queue is not the cause: the job starts in 2 s, and lint, mypy and install take under a minute.
The briefing tests added by #1206 to #1212 each built a whole briefing (maps, deck, PDF, kneeboard) to check one point.

## Change

a. **Build a briefing once per module, not once per test.**
A test that only reads a briefing takes it from a module- or class-scoped fixture; a test that writes into the folder, or builds it again with other content, keeps its own build or works on a copy.
Files: `test_mission_briefing_worker.py`, `test_build_mission_briefing.py`, `test_mission_promotion.py`, `test_objective_mission_v2.py`, `test_briefing_pdf.py`.

b. **Run the suite in parallel** with `pytest-xdist`.

## Definition of done

- Same number of tests before and after, every assertion kept, coverage within a few tenths.
- The parallel suite passes three times in a row locally.
- The CI `pytest` step measured before (last `develop` run) and after (the PR).
