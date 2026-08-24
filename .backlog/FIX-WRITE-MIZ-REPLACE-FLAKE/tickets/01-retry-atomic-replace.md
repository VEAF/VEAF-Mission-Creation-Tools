# 01 — Survive a transient lock on the final rename

Status: ✅ done 2026-08-20 — option 1, extended to all three atomic writes (see the PRD)
Type: fix
Files: `src/python/veaf-tools/veaf_libs/atomic_replace.py` (new),
`src/python/veaf-tools/mission_tools/miz_tools.py`,
`src/python/veaf-tools/veaf-tools-updater.py`,
`test/python/veaf_libs/test_atomic_replace.py` (new),
`test/python/mission_tools/test_miz_tools.py`, `test/python/mission_tools/test_miz_members.py`

## The change

Wrap the `os.replace(temp_zip_path, miz_file_path)` of `write_miz` in a bounded retry: a few
attempts with a short backoff, and **the original exception re-raised** when they run out, so a
genuine permission problem still fails and still names the real cause. No `except: pass` anywhere —
a write that did not happen must not return a mission object as if it had.

Two things to get right, both of which a naive retry gets wrong:

- **`path_to_clean_up` must stay set** until the rename actually succeeds, otherwise a failing retry
  leaves a `veaf_mission_*.miz` beside the mission — the exact litter VMR-053 removed.
- **The delay belongs on Windows only**, or at least it must not add latency to the Linux CI, where
  the failure does not exist.

## What the 2026-08-20 probe already settled

Do not re-investigate these — they are measured, in the PRD:

- the read-only attribute is **not** the cause (checked at the moment of failure, target writable);
- **one** retry after 50 ms cleared all 8 failures in 300 writes, and none ever needed a third
  attempt — so the retry can be short. Five attempts with a growing backoff is margin, not a guess;
- the failure reproduces with **no VEAF code involved**, so this is a guard against the environment,
  not a fix for a defect in `write_miz`.

## Tests

- The rename fails once, then succeeds → `write_miz` returns normally and **no temp file is left**.
- The rename fails every time → the original `PermissionError` reaches the caller, with its message
  intact, and no temp file is left.

Both by monkeypatching `os.replace`, so the test is deterministic and runs on Linux too — the
defect's own randomness must not get into its test.

## Done when

`poetry run pytest` passes ten consecutive full runs on this workstation, and the two tests above
exist. Ten runs rather than one: a single green run proves nothing about a flake that fires roughly
once per suite.
