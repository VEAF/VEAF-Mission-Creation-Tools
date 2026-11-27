# FIX-VEAF-LOGS-VIEWER-DEFECTS — three defects of the Python log viewer found by the Go port

Status: ✅ done · archived 2026-11-24

Merged in #1177 on 2026-10-24.

Origin: measuring parity between the Python `veaf-logs` and its Go rewrite ([FEAT-GO-VEAF-LOGS-ISOFUNCTIONAL](FEAT-GO-VEAF-LOGS-ISOFUNCTIONAL.md), J1, "Found in the Python viewer, not fixed here") surfaced three user-visible defects of the shipped Python viewer, 2026-10-24.

## Decisions

- `^` and `$` in a regex mean the start and end of a **line**, as a user reading a log expects, not of the 8 MB block the search happens to scan. The Go engine reproduced the block semantics for parity (`pythonDollar`); both sides move together in this lot and the goldens are regenerated.
- The leading and trailing `*` of a glob are dropped for the search only: they match the same entries, and the highlight keeps covering what it covered.

## Tickets

- [01 — *Aller à la fin* gets its shortcut](FIX-VEAF-LOGS-VIEWER-DEFECTS.md)
- [02 — `^` and `$` bind to lines](FIX-VEAF-LOGS-VIEWER-DEFECTS.md)
- [03 — A glob starting with `*` no longer freezes the window](FIX-VEAF-LOGS-VIEWER-DEFECTS.md)

## Tickets, in full

## 01 — *Aller à la fin* gets its shortcut

Status: ✅ done

`ui/main_window.py` declares `"Ctrl+Fin"`, which Qt does not parse (`QKeySequence("Ctrl+Fin")` is empty), so the action has no shortcut. Use `Ctrl+End`; a test asserts the action's shortcut is not empty.

## 02 — `^` and `$` bind to lines

Status: ✅ done

`filters._apply_text` runs the bytes pattern over `store.iter_blocks()` blocks without `re.MULTILINE`: `^` matches only the first entry of each 8 MB block, and `$` only before the block's final newline. Compile with `re.MULTILINE`; the Go engine (`internal/logcore/filters.go`) compiles with `(?m)` and drops `pythonDollar`; `testdata/gen_golden.py` is rerun so the goldens follow, and `go test ./...` stays green.

Found by the review: in multi-line mode, `^$` also matches the empty position past the block's final newline, which belongs to no line of the block and was brought back to the next entry (the last one on the test journal, which has no empty line). Both sides skip a match starting there; `^$` and `$` join the parity cases.

## 03 — A glob starting with `*` no longer freezes the window

Status: ✅ done

`*error*lua*` took 56.9 s on a 130 MB journal: the leading `.*` is retried from every position of every line. The search drops the leading and trailing `*` of a glob, which matches the same entries (a glob holds no anchor, and `.*` does not cross a line). A test compares the visible entries before and after on the shared test journal; timed with `src/go/veaf-logs/testdata/time_filters.py`.

Measured 2026-10-24 on the 954 086-entry journal, `time_filters.py`, case "glob + search ±2": 61.10 s before, 1.06 s after, 42 504 visible entries and the same SHA-1 on both; the Go side gives the same digest.
