# 01 — The filter engine of `filters.py`, in the Go core

Status: 🔄 in-progress

Milestone J1, toolkit-free.
`internal/logcore` has a case-insensitive plain search and nothing else; the viewer filters with `filters.py` (512 lines).

## Done when

- `internal/logcore/filters.go` gives the three modes (Texte, Jokers, Regex), case sensitivity, inversion, the tri-state categories (levels, sources, noise families; OFF beats CONTEXT beats ON), the category context with per-category spans, the search context with per-criterion spans, cumulative criteria, and the highlight patterns (rules R1–R6 of the PRD).
- A `FilterSet` reads and writes the same JSON as `FilterSet.to_dict` / `from_dict`, tolerances included (unknown state skipped, `true` not read as a span), so the Go viewer can later read the profiles and the session the Python one wrote.
- A parity test evaluates an **enumerated** set of filter cases on every corpus file and compares the visible indices with the golden written by the Python `evaluate`.
- Where Go's `regexp` (RE2) and Python's `re` cannot agree, the difference is measured, pinned by a test, and written in the PRD — not discovered by a user.
