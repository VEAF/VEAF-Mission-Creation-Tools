# CHORE-CI-JOB-TIMEOUTS — every CI job and apt-get step has a timeout

Status: ✅ done

Origin: 2026-10-22, David: run 39773630353 (`python-quality`, push of #1165 on `develop`) "dans les choux depuis 4h".
The job hung from 11:51 in its `apt-get update && apt-get install` step, a mirror that stopped answering; no workflow set `timeout-minutes`, so GitHub would have kept it six hours, a runner with it, and blocked any pull request whose required check it is.
The run was cancelled; the later `develop` runs had passed.

## Change

- Every job of the 16 workflows gets `timeout-minutes`: about three times its longest successful run over the last 80 runs (measured 2026-10-22: `python-quality` 15.2 min → 45, release build 3.9 → 30, everything else ≤ 4.5 → 10 or 15), 30 for the scheduled and manual workflows no sampled run covered. `go-ci.yml`, which landed on `develop` while this lot waited, gets 10 on its three jobs (longest of its last 15 runs: 83 s, measured 2026-10-25). The two release jobs that already had one keep it.
- Every `apt-get` step gets its own `timeout-minutes: 10`, so a hung mirror fails fast instead of eating the job's budget.
- `test_workflow_timeouts.py` fails on a job or an apt step without one (measured: fails on the workflows before this change, passes after).
