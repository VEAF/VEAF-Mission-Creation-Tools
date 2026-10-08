# 03 — `world.searchObjects` overshoots its sphere: a DCS trap, measured

Status: ⬜ ready

- `known-limitations.yaml`, `kind: dcs`: a `SPHERE` search of radius 2000 m returned units at 2036–2077 m of its centre (2D and 3D, units at y = 5 m), Caucasus, 2026-10-08, *Kolkhida* mission 1 — what it broke (a zone taken by a convoy that then did not become its garrison), and the workaround (filter by exact distance, or treat the search result as the definition everywhere, never mix the two).
- Regenerate `docs/agents/dcs-runtime-traps.md`.
- Update the known limitation `a-captured-zone-may-draw-a-garrison-under-its-convoy` (FIX-ASSAULT-CONVOY-FINDINGS) with the cause, and set its `fixed_in` when ticket 01 lands.
