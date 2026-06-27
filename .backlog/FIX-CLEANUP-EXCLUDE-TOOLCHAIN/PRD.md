# FIX-CLEANUP-EXCLUDE-TOOLCHAIN

Status: 🔄 in-progress

## Problem

The `convert-v5` leftover-file triage (CONVERT-V5-CLEANUP-FILES) listed
`veaf-tools.exe` and `veaf-tools-updater.exe` under *"files not managed by the
converter — review and delete if obsolete"*. Those are the **v6 toolchain binaries**
the mission-maker runs from the folder — suggesting to delete them is absurd, and
noisy (they sit in nearly every mission folder).

## Decision

The cleanup scan skips any `veaf-tools*.exe` binary entirely (never moved, never
deleted, never listed). Unrelated stray files are still listed as before.

## Implementation

- `mission_builder/v5_converter.py`: add `_CLEANUP_TOOLCHAIN_GLOBS = ("veaf-tools*.exe",)`
  and skip matching entries at the top of the root scan.
- Test: the two binaries are neither listed nor touched; an unrelated `stray.bin` still is.

## Out of scope

- The rest of the (b) listing (LICENSE/README/notes/built `.miz`/docs) — those are the
  maker's own content and being listed for review is the feature's intent; left as-is
  pending David's call on whether to narrow further.
