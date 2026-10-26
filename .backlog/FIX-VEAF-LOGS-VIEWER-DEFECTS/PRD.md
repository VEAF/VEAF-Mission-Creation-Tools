# FIX-VEAF-LOGS-VIEWER-DEFECTS — three defects of the Python log viewer found by the Go port

Status: ✅ done

Merged in #1177 on 2026-10-24.

Origin: measuring parity between the Python `veaf-logs` and its Go rewrite ([FEAT-GO-VEAF-LOGS-ISOFUNCTIONAL](../FEAT-GO-VEAF-LOGS-ISOFUNCTIONAL/PRD.md), J1, "Found in the Python viewer, not fixed here") surfaced three user-visible defects of the shipped Python viewer, 2026-10-24.

## Decisions

- `^` and `$` in a regex mean the start and end of a **line**, as a user reading a log expects, not of the 8 MB block the search happens to scan. The Go engine reproduced the block semantics for parity (`pythonDollar`); both sides move together in this lot and the goldens are regenerated.
- The leading and trailing `*` of a glob are dropped for the search only: they match the same entries, and the highlight keeps covering what it covered.

## Tickets

- [01 — *Aller à la fin* gets its shortcut](tickets/01-scroll-to-end-shortcut.md)
- [02 — `^` and `$` bind to lines](tickets/02-anchors-bind-to-lines.md)
- [03 — A glob starting with `*` no longer freezes the window](tickets/03-glob-leading-star.md)
