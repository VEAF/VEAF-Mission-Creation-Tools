# 03 — A glob starting with `*` no longer freezes the window

Status: ✅ done

`*error*lua*` took 56.9 s on a 130 MB journal: the leading `.*` is retried from every position of every line. The search drops the leading and trailing `*` of a glob, which matches the same entries (a glob holds no anchor, and `.*` does not cross a line). A test compares the visible entries before and after on the shared test journal; timed with `src/go/veaf-logs/testdata/time_filters.py`.

Measured 2026-10-24 on the 954 086-entry journal, `time_filters.py`, case "glob + search ±2": 61.10 s before, 1.06 s after, 42 504 visible entries and the same SHA-1 on both; the Go side gives the same digest.
