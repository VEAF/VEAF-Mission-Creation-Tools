# 04 — The topmost overlay decides

Status: ✅ done

A point is in a forest when the overlay drawn on top of it is a forest, as the F10 map shows it.

- Every overlay is indexed, not only the forests: each one's draw order is the u32 written after its material (Syria: Trees 93, fields 82-89, towns 94-114, sea 109; Marianas WWII: Forest 48-60, Field 56-100, Runway 103).
- A point inside a forest triangle is out of the forest when an overlay of higher draw order covers it; a tie keeps the forest.
- Overlays whose vertices are offsets from their base vertex (a float `parametricUVW`: roads, rivers, beaches, the coast's breaking waves) are not read: their shape is not in `Pbase`. A vehicle on a road through a wood therefore still counts as in the wood.
- Each mesh's arrays are now read as the chain of records that ends at its `TRI`, so an array of the previous mesh can no longer be taken for one of its own.

Checked on 2026-11-16: David's six Syria places still right, and the parking stands of the eleven maps (see the PRD).
