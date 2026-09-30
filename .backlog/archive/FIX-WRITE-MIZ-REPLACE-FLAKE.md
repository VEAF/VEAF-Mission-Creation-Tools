# FIX-WRITE-MIZ-REPLACE-FLAKE — `write_miz` fails at random on Windows, and only in a full suite

Status: ✅ done — 2026-08-20. **David chose option 1** (a bounded retry inside the writer) the day it was proposed · archived 2026-09-28

Origin: found in passing during the 2026-08-19 session and recorded in that day's handoff without a
lot; reproduced on 2026-08-20 while unblocking PR #762, which is what finally produced the error
message the diagnosis was missing.

## What is measured

`poetry run pytest` fails on one or two tests, **different ones on each run**, always green when
their file runs alone. Six occurrences so far on six different tests; the first predates the
2026-08-19 work, so it is not a regression of any recent lot. The CI never sees it — the runners are
Linux.

The 2026-08-20 occurrences, with the full trace:

```
test/python/veaf_mission_mcp/test_set_group_properties.py::TestFlags::
    test_each_flag_is_written[hidden-hidden]
test/python/veaf_mission_mcp/test_add_trigger_zone.py::
    TestAddTriggerZone::test_fresh_zone_id_past_existing_ones
test/python/veaf_mission_mcp/test_map_drawings.py::
    TestSurvivesAndBacksUp::test_a_backup_is_taken_before_the_write

miz_tools.py:455 → os.replace(temp_zip_path, miz_file_path)

PermissionError: [WinError 5] Access is denied:
  '...\veaf_mission_x7xtxlt1.miz' -> '...\mission.miz'
```

## What the code does, and why that shape is deliberate

`write_miz` creates its temp file with `tempfile.mkstemp(dir=miz_file_path.parent)`, closes the
handle immediately, writes the zip, then `os.replace`s it onto the target
(`mission_tools/miz_tools.py:355-455`). The comment above it records why: holding the handle open in
a `NamedTemporaryFile` context used to make Windows cleanup impossible (VMR-053), and the temp file
sits in the target's own directory so the move is atomic. **None of that should change** — the write
is correct, and it fails at the last step, on the rename.

## The cause, measured on 2026-08-20 — it is not our code

A probe reproducing only the *shape* of the write — `mkstemp`, write a 40 KB zip, `os.replace` — with
**no VEAF code involved at all**, run 300 times on this workstation:

| | |
|---|---|
| First `os.replace` failed | **8 of 300** (~2.7%), always `WinError 5` |
| Target's read-only attribute set at the moment of failure | **never** — the cheap explanation is ruled out |
| Retried once after 50 ms | **8 of 8 succeeded**; no failure ever needed a third attempt |
| Still failing after 6 attempts over ~1 s | **0** |

So: something external holds a handle on the freshly written file for a few tens of milliseconds —
on this machine, most plausibly the corporate antivirus scanning a newly created `.miz`. It is not
specific to the test bench: the probe writes no test fixture, and any Windows machine with a scanner
can hit the same window during a real build. The failure is **transient and self-clearing**, which is
the fact the fix hangs on.

The one thing still unproven is *which* process holds the handle. Naming it would need
`handle.exe`/Process Explorer at the moment of failure, and it does not change what the fix has to
do — so it is not worth blocking on.

## The open question, for David

A retry on `PermissionError` is a **change of behaviour**, not a bug fix: it makes a write that
currently fails succeed a moment later. That is why the 2026-08-19 session deliberately did not do
it. The measurement above narrows the cost of each answer:

1. **A bounded retry inside `write_miz`** — a few attempts over ~1 s, then the original error raised.
   Fixes it for every caller, including a mission maker whose own machine has an antivirus, which is
   most of them. Measured cost: **50 ms on ~2.7% of writes**, and a genuine permission error is
   reported ~1 s later than today.
2. **A retry in the test helper only** — production behaviour untouched, and it admits the product is
   fine and the test environment is not. But the probe shows the window has nothing to do with the
   tests, so a mission maker keeps hitting it mid-build, where it costs them the edit they just made.
3. **Nothing, and document it** — records the cause so nobody re-investigates a red suite. A full
   Windows run stays a coin toss (2 failures in one run, measured).

The recommendation was **1**, and the measurement is what made it cheap: one retry after 50 ms
cleared all 8 failures out of 300 writes, so the guard costs nothing on a healthy write and turns a
lost mission edit into a 50 ms pause. **David chose 1 on 2026-08-20.**

## What was widened, and why — a decision taken alone

The ticket named one call site, `write_miz`. Enumerating `os.replace` across the tooling found
**three** atomic writes of exactly the same shape, all vulnerable to the same window:

| Site | What it writes |
|---|---|
| `miz_tools.py` — `write_miz` | a `.miz`, the reported case |
| `miz_tools.py` — `rewrite_miz_members` | a `.miz`, byte-for-byte member swap — same file, same window |
| `veaf-tools-updater.py` — `_install_binary` | a **freshly downloaded `.exe`**, the file a scanner is most certain to open, and the rename that installs an update |

Fixing only the reported one would have left two armed traps, one of them more exposed than the
original — the same reasoning `FIX-CTLD-NEVER-INITIALIZED` ticket 02 recorded when its guard went
from 1 site to 9. So the retry went into a shared `veaf_libs/atomic_replace.py` and all three call
it. That is an extension of the agreed scope, decided alone, and open to review.

Left alone on purpose: `write_mission_folder` and the YAML writers, which do not rename anything —
they write in place, so they have no such window.

## Scope

| # | Ticket | Status |
|---|--------|--------|
| 01 | [Survive a transient lock on the final rename](FIX-WRITE-MIZ-REPLACE-FLAKE.md) | ✅ |

## Out of scope

- **Changing the atomic-write shape.** The `mkstemp` + `os.replace` pair is the fix for VMR-053 and
  stays untouched — the guard wraps it, it does not replace it.
- **Naming the process that holds the handle.** It would need `handle.exe` at the moment of failure
  and would not change what the fix does.
- **A platform check.** None is needed: the retry only fires on `PermissionError`, which this rename
  does not raise on Linux, so the CI never sleeps and no `sys.platform` test had to be written.

---

## Tickets, in full

## 01 — Survive a transient lock on the final rename

Status: ✅ done 2026-08-20 — option 1, extended to all three atomic writes (see the PRD)
Type: fix
Files: `src/python/veaf-tools/veaf_libs/atomic_replace.py` (new),
`src/python/veaf-tools/mission_tools/miz_tools.py`,
`src/python/veaf-tools/veaf-tools-updater.py`,
`test/python/veaf_libs/test_atomic_replace.py` (new),
`test/python/mission_tools/test_miz_tools.py`, `test/python/mission_tools/test_miz_members.py`

### The change

Wrap the `os.replace(temp_zip_path, miz_file_path)` of `write_miz` in a bounded retry: a few
attempts with a short backoff, and **the original exception re-raised** when they run out, so a
genuine permission problem still fails and still names the real cause. No `except: pass` anywhere —
a write that did not happen must not return a mission object as if it had.

Two things to get right, both of which a naive retry gets wrong:

- **`path_to_clean_up` must stay set** until the rename actually succeeds, otherwise a failing retry
  leaves a `veaf_mission_*.miz` beside the mission — the exact litter VMR-053 removed.
- **The delay belongs on Windows only**, or at least it must not add latency to the Linux CI, where
  the failure does not exist.

### What the 2026-08-20 probe already settled

Do not re-investigate these — they are measured, in the PRD:

- the read-only attribute is **not** the cause (checked at the moment of failure, target writable);
- **one** retry after 50 ms cleared all 8 failures in 300 writes, and none ever needed a third
  attempt — so the retry can be short. Five attempts with a growing backoff is margin, not a guess;
- the failure reproduces with **no VEAF code involved**, so this is a guard against the environment,
  not a fix for a defect in `write_miz`.

### Tests

- The rename fails once, then succeeds → `write_miz` returns normally and **no temp file is left**.
- The rename fails every time → the original `PermissionError` reaches the caller, with its message
  intact, and no temp file is left.

Both by monkeypatching `os.replace`, so the test is deterministic and runs on Linux too — the
defect's own randomness must not get into its test.

### Done when

`poetry run pytest` passes ten consecutive full runs on this workstation, and the two tests above
exist. Ten runs rather than one: a single green run proves nothing about a flake that fires roughly
once per suite.

---
