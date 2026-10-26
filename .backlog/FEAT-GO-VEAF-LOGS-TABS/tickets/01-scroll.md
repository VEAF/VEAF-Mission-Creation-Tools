# 01 — The strip scrolls

Status: ✅ done

The wheel over the strip scrolls it; ‹ › arrows at its right edge when the tabs overflow; the current tab is brought into view whenever it changes.

## Done when

- `internal/logview` tests for the offset: clamped to the overflow, the current tab brought into view from either side, no scroll without overflow.
